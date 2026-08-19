package com.rohit.ble_peripheral

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

internal class PeerSessionTrackerTest {
    @Test
    fun unpairedPeerIsRetainedAcrossPairingDisconnectAndReconnect() {
        val tracker = PeerSessionTracker()

        val connected = tracker.onLinkConnected("peer-a", PeerBondState.NONE)
        val initial = assertNotNull(connected.snapshot)
        assertTrue(connected.accepted)
        assertTrue(connected.connectionChanged)
        assertTrue(connected.shouldCreateBond)
        assertTrue(tracker.markBondRequested("peer-a", initial.generation))

        val bonding = tracker.onBondStateChanged("peer-a", PeerBondState.BONDING)
        assertFalse(bonding.pairingFailed)
        assertEquals(PeerBondState.BONDING, bonding.snapshot?.bondState)

        val disconnected = tracker.onLinkDisconnected(
            address = "peer-a",
            keepBondedPeerForReconnect = true,
        )
        assertTrue(disconnected.accepted)
        assertTrue(disconnected.retainedForReconnect)
        assertFalse(disconnected.snapshot!!.linkConnected)

        val bonded = tracker.onBondStateChanged("peer-a", PeerBondState.BONDED)
        assertFalse(bonded.pairingFailed)
        assertEquals(PeerBondState.BONDED, bonded.snapshot?.bondState)

        val reconnected = tracker.onLinkConnected("peer-a", PeerBondState.BONDED)
        assertTrue(reconnected.accepted)
        assertEquals(initial.generation, reconnected.snapshot?.generation)
        assertFalse(reconnected.shouldCreateBond)

        val subscription = tracker.onSubscriptionChanged(
            address = "peer-a",
            characteristicId = "state-notify",
            isSubscribed = true,
        )
        assertTrue(subscription.accepted)
        assertTrue(subscription.changed)
        assertTrue(subscription.snapshot!!.isReadyFor("state-notify"))
    }

    @Test
    fun existingBondDoesNotRequestPairingAndKeepsTheSameSessionOnReconnect() {
        val tracker = PeerSessionTracker()

        val connected = tracker.onLinkConnected("peer-a", PeerBondState.BONDED)
        assertTrue(connected.accepted)
        assertFalse(connected.shouldCreateBond)
        val initialGeneration = connected.snapshot!!.generation

        val subscribed = tracker.onSubscriptionChanged("peer-a", "state-notify", true)
        assertTrue(subscribed.changed)
        assertFalse(tracker.onSubscriptionChanged("peer-a", "state-notify", true).changed)

        val disconnected = tracker.onLinkDisconnected("peer-a", keepBondedPeerForReconnect = true)
        assertTrue(disconnected.retainedForReconnect)
        assertEquals(setOf("state-notify"), disconnected.subscriptionsToClear)

        val reconnected = tracker.onLinkConnected("peer-a", PeerBondState.BONDED)
        assertEquals(initialGeneration, reconnected.snapshot?.generation)
        assertTrue(reconnected.snapshot!!.linkConnected)
        assertTrue(reconnected.snapshot!!.subscriptions.isEmpty())
    }

    @Test
    fun subscriptionBeforeBondIsTrackedButCannotMakeThePeerReady() {
        val tracker = PeerSessionTracker()
        val connected = tracker.onLinkConnected("peer-a", PeerBondState.NONE)
        assertTrue(tracker.markBondRequested("peer-a", connected.snapshot!!.generation))

        val subscription = tracker.onSubscriptionChanged("peer-a", "state-notify", true)
        assertTrue(subscription.changed)
        assertFalse(subscription.snapshot!!.isReadyFor("state-notify"))

        tracker.onBondStateChanged("peer-a", PeerBondState.BONDING)
        val bonded = tracker.onBondStateChanged("peer-a", PeerBondState.BONDED)
        assertTrue(bonded.snapshot!!.isReadyFor("state-notify"))
    }

    @Test
    fun rejectedPairingClearsThePeerAndRejectsLateCallbacks() {
        val tracker = PeerSessionTracker()

        val connected = tracker.onLinkConnected("peer-a", PeerBondState.NONE)
        val generation = connected.snapshot!!.generation
        assertTrue(tracker.markBondRequested("peer-a", generation))
        assertFalse(tracker.onBondStateChanged("peer-a", PeerBondState.BONDING).pairingFailed)

        val rejected = tracker.onBondStateChanged("peer-a", PeerBondState.NONE)
        assertTrue(rejected.pairingFailed)
        assertNull(tracker.snapshot())
        assertFalse(tracker.onBondStateChanged("peer-a", PeerBondState.BONDED).accepted)

        val nextPeer = tracker.onLinkConnected("peer-b", PeerBondState.BONDED)
        assertTrue(nextPeer.accepted)
        assertTrue(nextPeer.snapshot!!.generation > generation)
    }

    @Test
    fun aSecondPeerIsRejectedUntilTheCurrentSessionIsReleased() {
        val tracker = PeerSessionTracker()
        val first = tracker.onLinkConnected("peer-a", PeerBondState.BONDED)
        assertTrue(first.accepted)
        tracker.onSubscriptionChanged("peer-a", "state-notify", true)

        val second = tracker.onLinkConnected("peer-b", PeerBondState.BONDED)
        assertFalse(second.accepted)

        val released = tracker.onLinkDisconnected("peer-a", keepBondedPeerForReconnect = false)
        assertFalse(released.retainedForReconnect)
        assertTrue(tracker.onLinkConnected("peer-b", PeerBondState.BONDED).accepted)
    }

    @Test
    fun cancellingAnUnfinishedAttemptInvalidatesLateBondCallbacks() {
        val tracker = PeerSessionTracker()
        val connected = tracker.onLinkConnected("peer-a", PeerBondState.NONE)
        assertTrue(tracker.markBondRequested("peer-a", connected.snapshot!!.generation))

        assertNotNull(tracker.clearIfNotReadyFor("state-notify"))
        assertFalse(tracker.onBondStateChanged("peer-a", PeerBondState.BONDED).accepted)
    }

    @Test
    fun controlOnlySubscriptionDoesNotPreserveAStoppedAttempt() {
        val tracker = PeerSessionTracker()
        tracker.onLinkConnected("peer-a", PeerBondState.BONDED)
        tracker.onSubscriptionChanged("peer-a", "control-notify", true)

        assertNotNull(tracker.clearIfNotReadyFor("state-notify"))
        assertNull(tracker.snapshot())
    }

    @Test
    fun staleBondingCallbackCannotDowngradeAnAlreadyBondedPeer() {
        val tracker = PeerSessionTracker()
        tracker.onLinkConnected("peer-a", PeerBondState.BONDED)

        val stale = tracker.onBondStateChanged("peer-a", PeerBondState.BONDING)
        assertTrue(stale.accepted)
        assertFalse(stale.stateChanged)
        assertEquals(PeerBondState.BONDED, stale.snapshot?.bondState)
    }
}
