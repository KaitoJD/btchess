package com.rohit.ble_peripheral

/**
 * Keeps the Android GATT-server callbacks scoped to one peer/session.
 *
 * Android can deliver bond, link, and CCCD callbacks independently (and a
 * pairing flow can temporarily drop the GATT link).  This class deliberately
 * has no Android dependencies so its transition rules can be unit tested.
 */
internal enum class PeerBondState {
    NONE,
    BONDING,
    BONDED,
}

internal data class PeerSnapshot(
    val address: String,
    val generation: Long,
    val linkConnected: Boolean,
    val bondState: PeerBondState,
    val bondRequested: Boolean,
    val subscriptions: Set<String>,
) {
    fun isReadyFor(requiredSubscriptionId: String): Boolean {
        return linkConnected &&
                bondState == PeerBondState.BONDED &&
                subscriptions.any { it.equals(requiredSubscriptionId, ignoreCase = true) }
    }
}

internal data class PeerConnectionUpdate(
    val accepted: Boolean,
    val snapshot: PeerSnapshot? = null,
    val connectionChanged: Boolean = false,
    val shouldCreateBond: Boolean = false,
)

internal data class PeerDisconnectUpdate(
    val accepted: Boolean,
    val snapshot: PeerSnapshot? = null,
    val connectionChanged: Boolean = false,
    val subscriptionsToClear: Set<String> = emptySet(),
    val retainedForReconnect: Boolean = false,
)

internal data class PeerBondUpdate(
    val accepted: Boolean,
    val snapshot: PeerSnapshot? = null,
    val pairingFailed: Boolean = false,
    val stateChanged: Boolean = false,
)

internal data class PeerSubscriptionUpdate(
    val accepted: Boolean,
    val snapshot: PeerSnapshot? = null,
    val changed: Boolean = false,
)

internal class PeerSessionTracker {
    private data class PeerSession(
        val address: String,
        val generation: Long,
        var linkConnected: Boolean,
        var bondState: PeerBondState,
        var bondRequested: Boolean = false,
        val subscriptions: LinkedHashSet<String> = linkedSetOf(),
    ) {
        fun snapshot(): PeerSnapshot {
            return PeerSnapshot(
                address = address,
                generation = generation,
                linkConnected = linkConnected,
                bondState = bondState,
                bondRequested = bondRequested,
                subscriptions = subscriptions.toSet(),
            )
        }
    }

    private var nextGeneration = 0L
    private var session: PeerSession? = null

    /**
     * Accepts the first peer, or a reconnect from that peer. A different peer
     * is rejected until the active session has finished or been cleared.
     */
    @Synchronized
    fun onLinkConnected(
        address: String,
        observedBondState: PeerBondState,
    ): PeerConnectionUpdate {
        val current = session
        if (current != null && current.address != address) {
            return PeerConnectionUpdate(accepted = false)
        }

        val peer = current ?: PeerSession(
            address = address,
            generation = ++nextGeneration,
            linkConnected = false,
            bondState = observedBondState,
        ).also { session = it }

        // A freshly observed upgraded state is safe to adopt. Do not downgrade
        // an in-flight/complete bond from a stale connection callback; a bond
        // broadcast is authoritative for a downgrade.
        when (observedBondState) {
            PeerBondState.BONDED -> {
                peer.bondState = PeerBondState.BONDED
                peer.bondRequested = false
            }

            PeerBondState.BONDING -> {
                if (peer.bondState == PeerBondState.NONE) {
                    peer.bondState = PeerBondState.BONDING
                }
                peer.bondRequested = true
            }

            PeerBondState.NONE -> Unit
        }

        val connectionChanged = !peer.linkConnected
        peer.linkConnected = true
        if (connectionChanged) {
            // CCCD values belong to a physical GATT connection, not the bond.
            peer.subscriptions.clear()
        }

        return PeerConnectionUpdate(
            accepted = true,
            snapshot = peer.snapshot(),
            connectionChanged = connectionChanged,
            shouldCreateBond =
                peer.bondState == PeerBondState.NONE && !peer.bondRequested,
        )
    }

    @Synchronized
    fun markBondRequested(address: String, generation: Long): Boolean {
        val peer = currentPeer(address, generation) ?: return false
        if (peer.bondState != PeerBondState.NONE || peer.bondRequested) {
            return false
        }
        peer.bondRequested = true
        return true
    }

    /** Records the system bond broadcast for the current peer only. */
    @Synchronized
    fun onBondStateChanged(
        address: String,
        bondState: PeerBondState,
    ): PeerBondUpdate {
        val peer = session
        if (peer == null || peer.address != address) {
            return PeerBondUpdate(accepted = false)
        }

        val previousState = peer.bondState
        when (bondState) {
            PeerBondState.BONDING -> {
                if (previousState == PeerBondState.BONDED) {
                    // A delayed BONDING broadcast must not regress an already
                    // complete bond or revive the setup flow.
                    return PeerBondUpdate(
                        accepted = true,
                        snapshot = peer.snapshot(),
                        stateChanged = false,
                    )
                }
                if (previousState == PeerBondState.BONDING) {
                    return PeerBondUpdate(
                        accepted = true,
                        snapshot = peer.snapshot(),
                        stateChanged = false,
                    )
                }
                peer.bondState = PeerBondState.BONDING
                peer.bondRequested = true
            }

            PeerBondState.BONDED -> {
                if (previousState == PeerBondState.BONDED) {
                    return PeerBondUpdate(
                        accepted = true,
                        snapshot = peer.snapshot(),
                        stateChanged = false,
                    )
                }
                peer.bondState = PeerBondState.BONDED
                peer.bondRequested = false
            }

            PeerBondState.NONE -> {
                val pairingFailed = peer.bondRequested || previousState != PeerBondState.NONE
                peer.bondState = PeerBondState.NONE
                peer.bondRequested = false
                val snapshot = peer.snapshot()
                if (pairingFailed) {
                    // A BONDING -> NONE transition is the Android signal for a
                    // rejected/cancelled pairing. Clear it so late callbacks
                    // cannot revive this session.
                    session = null
                }
                return PeerBondUpdate(
                    accepted = true,
                    snapshot = snapshot,
                    pairingFailed = pairingFailed,
                    stateChanged = pairingFailed || previousState != PeerBondState.NONE,
                )
            }
        }

        return PeerBondUpdate(
            accepted = true,
            snapshot = peer.snapshot(),
            stateChanged = true,
        )
    }

    /**
     * Keeps a pairing/reconnect candidate after a transient link loss. Once
     * advertising has stopped, a bonded peer is treated as an established
     * session and is released on its eventual real disconnect.
     */
    @Synchronized
    fun onLinkDisconnected(
        address: String,
        keepBondedPeerForReconnect: Boolean,
    ): PeerDisconnectUpdate {
        val peer = session
        if (peer == null || peer.address != address) {
            return PeerDisconnectUpdate(accepted = false)
        }
        if (!peer.linkConnected) {
            return PeerDisconnectUpdate(
                accepted = true,
                snapshot = peer.snapshot(),
            )
        }

        val subscriptions = peer.subscriptions.toSet()
        peer.subscriptions.clear()
        peer.linkConnected = false
        val retainedForReconnect =
            peer.bondRequested ||
                    peer.bondState == PeerBondState.BONDING ||
                    (peer.bondState == PeerBondState.BONDED && keepBondedPeerForReconnect)
        val snapshot = peer.snapshot()
        if (!retainedForReconnect) {
            session = null
        }

        return PeerDisconnectUpdate(
            accepted = true,
            snapshot = snapshot,
            connectionChanged = true,
            subscriptionsToClear = subscriptions,
            retainedForReconnect = retainedForReconnect,
        )
    }

    @Synchronized
    fun onSubscriptionChanged(
        address: String,
        characteristicId: String,
        isSubscribed: Boolean,
    ): PeerSubscriptionUpdate {
        val peer = session
        if (peer == null || peer.address != address || !peer.linkConnected) {
            return PeerSubscriptionUpdate(accepted = false)
        }

        val changed = if (isSubscribed) {
            peer.subscriptions.add(characteristicId)
        } else {
            peer.subscriptions.remove(characteristicId)
        }

        return PeerSubscriptionUpdate(
            accepted = true,
            snapshot = peer.snapshot(),
            changed = changed,
        )
    }

    @Synchronized
    fun currentGenerationIfConnected(address: String): Long? {
        val peer = session
        return if (peer?.address == address && peer.linkConnected) {
            peer.generation
        } else {
            null
        }
    }

    @Synchronized
    fun isCurrentConnected(address: String, generation: Long): Boolean {
        val peer = session
        return peer?.address == address &&
                peer.generation == generation &&
                peer.linkConnected
    }

    /**
     * Advertising is stopped only after the host considers a peer ready. If it
     * is stopped before that point (cancel/timeout), discard the unfinished
     * peer so delayed Android callbacks are ignored.
     */
    @Synchronized
    fun clearIfNotReadyFor(requiredSubscriptionId: String): PeerSnapshot? {
        val peer = session ?: return null
        if (peer.snapshot().isReadyFor(requiredSubscriptionId)) {
            return null
        }
        val snapshot = peer.snapshot()
        session = null
        return snapshot
    }

    @Synchronized
    fun clear(): PeerSnapshot? {
        val peer = session ?: return null
        val snapshot = peer.snapshot()
        session = null
        return snapshot
    }

    @Synchronized
    fun snapshot(): PeerSnapshot? = session?.snapshot()

    private fun currentPeer(address: String, generation: Long): PeerSession? {
        val peer = session
        return if (peer?.address == address && peer.generation == generation) {
            peer
        } else {
            null
        }
    }
}
