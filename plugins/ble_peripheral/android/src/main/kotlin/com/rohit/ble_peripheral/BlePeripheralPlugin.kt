package com.rohit.ble_peripheral

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Context.RECEIVER_EXPORTED
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import androidx.core.app.ActivityCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

private const val TAG = "BlePeripheralPlugin"
// BTChess local-plugin contract: only this subscription makes a host peer
// protocol-ready. CONTROL notifications alone must not preserve a cancelled
// pairing attempt.
private const val BTCHESS_STATE_NOTIFY_CHARACTERISTIC_UUID =
    "0000c0de-0002-1000-8000-00805f9b34fb"

/**
 * Android BLE peripheral implementation.
 *
 * Connection callbacks are deliberately raw GATT-link events. A Dart caller
 * must wait for the corresponding bond and required CCCD subscription before
 * treating a peer as protocol-ready.
 */
@SuppressLint("MissingPermission")
class BlePeripheralPlugin : FlutterPlugin, BlePeripheralChannel, ActivityAware {
    private val requestCodeBluetoothPermission = 0xa1c
    private val requestCodeBluetoothEnablePermission = 0xb1e
    private val emptyBytes = byteArrayOf()

    private var bleCallback: BleCallback? = null
    private var applicationContext: Context? = null
    private var activity: Activity? = null
    private var bluetoothManager: BluetoothManager? = null
    private var handler: Handler? = null
    private var bluetoothLeAdvertiser: BluetoothLeAdvertiser? = null
    private var gattServer: BluetoothGattServer? = null

    // This map contains only peers with a currently-live GATT link. A separate
    // tracker retains a bonding peer across a pairing-induced disconnect.
    private val bluetoothDevicesMap: MutableMap<String, BluetoothDevice> = HashMap()
    private val peerSessions = PeerSessionTracker()

    private var isAdvertising: Boolean? = null
    private var advertisingRequested = false
    private var advertisingStartPending = false
    private var advertisingGeneration = 0L
    private var activeAdvertiseCallback: AdvertiseCallback? = null
    private var receiverRegistered = false

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        BlePeripheralChannel.setUp(flutterPluginBinding.binaryMessenger, this)
        bleCallback = BleCallback(flutterPluginBinding.binaryMessenger)
        applicationContext = flutterPluginBinding.applicationContext
        registerBroadcastReceiver()
    }

    override fun initialize() {
        val context = applicationContext ?: throw Exception("Application context is null")
        handler = handler ?: Handler(context.mainLooper)
        bluetoothManager =
            bluetoothManager ?: context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val bluetoothAdapter = bluetoothManager?.adapter
            ?: throw UnsupportedOperationException("Bluetooth is not available.")
        bluetoothLeAdvertiser = bluetoothAdapter.bluetoothLeAdvertiser
        if (bluetoothLeAdvertiser == null) {
            throw UnsupportedOperationException("Bluetooth LE Advertising not supported on this device.")
        }
        if (gattServer == null) {
            gattServer = bluetoothManager?.openGattServer(context, gattServerCallback)
            if (gattServer == null) {
                throw UnsupportedOperationException("gattServer is null, check Bluetooth is ON.")
            }
        }
        emitBleState(isBluetoothEnabled())
    }

    override fun isAdvertising(): Boolean? = isAdvertising

    override fun isSupported(): Boolean {
        val bluetoothAdapter = bluetoothManager?.adapter ?: return false
        if (!bluetoothAdapter.isMultipleAdvertisementSupported) {
            throw UnsupportedOperationException("Bluetooth LE Advertising not supported on this device.")
        }
        return true
    }

    override fun addService(service: BleService) {
        gattServer?.addService(service.toGattService())
    }

    override fun removeService(serviceId: String) {
        serviceId.findService()?.let { gattServer?.removeService(it) }
    }

    override fun clearServices() {
        gattServer?.clearServices()
    }

    override fun getServices(): List<String> {
        return gattServer?.services?.map { it.uuid.toString() } ?: emptyList()
    }

    override fun startAdvertising(
        services: List<String>,
        localName: String?,
        timeout: Long?,
        manufacturerData: ManufacturerData?,
        addManufacturerDataInScanResponse: Boolean,
    ) {
        if (!isBluetoothEnabled()) {
            enableBluetooth()
            throw Exception("Bluetooth is not enabled")
        }

        // Pairing and a central reconnect can overlap. Keep the original
        // advertisement alive instead of issuing a second start request.
        if (advertisingRequested || advertisingStartPending || isAdvertising == true) {
            return
        }
        advertisingRequested = true
        advertisingStartPending = true
        val generation = ++advertisingGeneration
        val callback = createAdvertiseCallback(generation)
        activeAdvertiseCallback = callback

        runOnMain {
            if (generation != advertisingGeneration || !advertisingRequested) {
                return@runOnMain
            }
            localName?.let { bluetoothManager?.adapter?.name = it }
            val advertiseSettings = AdvertiseSettings.Builder()
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
                .setConnectable(true)
                .setTimeout(timeout?.toInt() ?: 0)
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                .build()

            val advertiseDataBuilder = AdvertiseData.Builder()
                .setIncludeTxPowerLevel(false)
                .setIncludeDeviceName(localName != null)
            val scanResponseBuilder = AdvertiseData.Builder()
                .setIncludeTxPowerLevel(false)
                .setIncludeDeviceName(localName != null)

            manufacturerData?.let {
                if (addManufacturerDataInScanResponse) {
                    scanResponseBuilder.addManufacturerData(it.manufacturerId.toInt(), it.data)
                } else {
                    advertiseDataBuilder.addManufacturerData(it.manufacturerId.toInt(), it.data)
                }
            }
            services.forEach { advertiseDataBuilder.addServiceUuid(ParcelUuid.fromString(it)) }

            bluetoothLeAdvertiser?.startAdvertising(
                advertiseSettings,
                advertiseDataBuilder.build(),
                scanResponseBuilder.build(),
                callback,
            )
        }
    }

    override fun stopAdvertising() {
        advertisingRequested = false
        advertisingStartPending = false
        advertisingGeneration++
        val callback = activeAdvertiseCallback
        activeAdvertiseCallback = null

        // Stopping while a peer is still in setup is a cancel/timeout. Drop
        // that unfinished session so a delayed bond callback cannot revive it.
        peerSessions.clearIfNotReadyFor(BTCHESS_STATE_NOTIFY_CHARACTERISTIC_UUID)?.let { peer ->
            val device = removeConnectedDevice(peer.address)
            device?.let { gattServer?.cancelConnection(it) }
            logPeer("Cleared unfinished peer after advertising stopped", peer)
        }

        runOnMain {
            try {
                callback?.let { bluetoothLeAdvertiser?.stopAdvertising(it) }
                isAdvertising = false
                emitAdvertisingStatus(advertising = false, error = null)
            } catch (exception: IllegalStateException) {
                Log.w(TAG, "Unable to stop advertising because Bluetooth is unavailable")
            }
        }
    }

    override fun updateCharacteristic(
        characteristicId: String,
        value: ByteArray,
        deviceId: String?,
    ) {
        val characteristic =
            characteristicId.findCharacteristic() ?: throw Exception("Characteristic not found")
        characteristic.value = value

        if (deviceId != null) {
            val device = resolveDeviceForUpdate(deviceId) ?: throw Exception("Device not found")
            val generation = peerSessions.currentGenerationIfConnected(device.address)
                ?: throw Exception("Device is no longer connected")
            notifyCharacteristicChanged(device, characteristic, generation)
            return
        }

        val targets = synchronized(bluetoothDevicesMap) {
            bluetoothDevicesMap.values.toList()
        }
        targets.forEach { device ->
            val generation = peerSessions.currentGenerationIfConnected(device.address) ?: return@forEach
            notifyCharacteristicChanged(device, characteristic, generation)
        }
    }

    private fun notifyCharacteristicChanged(
        device: BluetoothDevice,
        characteristic: BluetoothGattCharacteristic,
        generation: Long,
    ) {
        runOnMain {
            if (!peerSessions.isCurrentConnected(device.address, generation)) {
                Log.d(TAG, "Skipped stale characteristic update for peer=${redactDeviceId(device.address)}")
                return@runOnMain
            }
            gattServer?.notifyCharacteristicChanged(device, characteristic, true)
        }
    }

    private fun isBluetoothEnabled(): Boolean {
        val bluetoothAdapter: BluetoothAdapter? = bluetoothManager?.adapter
        return bluetoothAdapter?.isEnabled ?: false
    }

    private fun enableBluetooth() {
        activity?.startActivityForResult(
            Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE),
            requestCodeBluetoothEnablePermission,
        )
    }

    private fun registerConnectedDevice(device: BluetoothDevice) {
        synchronized(bluetoothDevicesMap) {
            bluetoothDevicesMap[device.address] = device
        }
    }

    private fun removeConnectedDevice(deviceAddress: String): BluetoothDevice? {
        return synchronized(bluetoothDevicesMap) {
            bluetoothDevicesMap.remove(deviceAddress)
        }
    }

    private fun resolveDeviceForUpdate(requestedDeviceId: String): BluetoothDevice? {
        synchronized(bluetoothDevicesMap) {
            bluetoothDevicesMap[requestedDeviceId]?.let { return it }

            // A reconnect can expose a fresh BluetoothDevice instance while the
            // Dart layer still has one stale identifier. Restrict the fallback
            // to exactly one currently accepted peer so it cannot leak data to
            // a second central.
            if (bluetoothDevicesMap.size == 1) {
                val fallback = bluetoothDevicesMap.values.first()
                if (peerSessions.currentGenerationIfConnected(fallback.address) != null) {
                    Log.w(
                        TAG,
                        "Using the sole connected peer for a stale characteristic update " +
                                "(requested=${redactDeviceId(requestedDeviceId)}, " +
                                "peer=${redactDeviceId(fallback.address)})",
                    )
                    return fallback
                }
            }

            Log.w(
                TAG,
                "Characteristic update target not connected " +
                        "(requested=${redactDeviceId(requestedDeviceId)}, " +
                        "connectedCount=${bluetoothDevicesMap.size})",
            )
            return null
        }
    }

    private fun handleConnectionStateChange(
        device: BluetoothDevice,
        status: Int,
        newState: Int,
    ) {
        when (newState) {
            BluetoothProfile.STATE_CONNECTED -> handleLinkConnected(device, status)
            BluetoothProfile.STATE_DISCONNECTED -> handleLinkDisconnected(device, status)
            else -> Log.d(TAG, "Ignored GATT state=$newState status=$status")
        }
    }

    private fun handleLinkConnected(device: BluetoothDevice, status: Int) {
        val update = peerSessions.onLinkConnected(device.address, device.bondState.toPeerBondState())
        if (!update.accepted) {
            Log.w(TAG, "Rejected a second GATT peer=${redactDeviceId(device.address)}")
            gattServer?.cancelConnection(device)
            return
        }

        val peer = update.snapshot ?: return
        // Register raw GATT connectivity before pairing. It is intentionally
        // not a protocol-ready signal.
        registerConnectedDevice(device)
        logPeer("Raw GATT link connected (status=$status)", peer)

        if (update.connectionChanged) {
            // These callbacks use distinct Pigeon channels, so wait until the
            // raw link callback has reached Dart before publishing bond state.
            // That prevents a fast BOND_BONDED peer from being dropped by a
            // Dart state machine that has not selected its peer yet.
            emitConnectionState(device.address, connected = true) {
                publishCurrentBondStateAndRequestPairing(
                    device = device,
                    generation = peer.generation,
                    shouldCreateBond = update.shouldCreateBond,
                )
            }
        } else {
            publishCurrentBondStateAndRequestPairing(
                device = device,
                generation = peer.generation,
                shouldCreateBond = update.shouldCreateBond,
            )
        }
    }

    private fun publishCurrentBondStateAndRequestPairing(
        device: BluetoothDevice,
        generation: Long,
        shouldCreateBond: Boolean,
    ) {
        if (!peerSessions.isCurrentConnected(device.address, generation)) {
            return
        }
        val peer = peerSessions.snapshot() ?: return
        // Android does not broadcast a change for an already-bonded peer, so
        // always publish its current state immediately on raw connection.
        emitBondState(device.address, peer.bondState)

        if (shouldCreateBond && peerSessions.markBondRequested(device.address, generation)) {
            val started = device.createBond()
            if (!started) {
                Log.w(TAG, "createBond was not accepted for peer=${redactDeviceId(device.address)}")
            } else {
                Log.d(TAG, "Requested system pairing for peer=${redactDeviceId(device.address)}")
            }
        }
    }

    private fun handleLinkDisconnected(device: BluetoothDevice, status: Int) {
        val keepBondedPeerForReconnect = advertisingRequested || isAdvertising == true
        val update = peerSessions.onLinkDisconnected(
            address = device.address,
            keepBondedPeerForReconnect = keepBondedPeerForReconnect,
        )
        if (!update.accepted || !update.connectionChanged) {
            return
        }

        removeConnectedDevice(device.address)
        val peer = update.snapshot ?: return
        logPeer(
            "Raw GATT link disconnected (status=$status, retained=${update.retainedForReconnect})",
            peer,
        )
        // Preserve raw link semantics for Dart. Subscription callbacks follow
        // so clients can clear their per-link CCCD state deterministically.
        emitConnectionState(device.address, connected = false)
        update.subscriptionsToClear.forEach { characteristicId ->
            emitSubscriptionState(
                deviceId = device.address,
                characteristicId = characteristicId,
                isSubscribed = false,
                name = device.name,
            )
        }
    }

    private fun handleBondStateChange(device: BluetoothDevice, bondState: PeerBondState) {
        val update = peerSessions.onBondStateChanged(device.address, bondState)
        if (!update.accepted || !update.stateChanged) {
            // Ignore external/stale bond broadcasts that do not belong to the
            // selected peer/session, including a delayed BONDING event after
            // this peer is already BONDED.
            return
        }

        val peer = update.snapshot ?: return
        logPeer("Bond state changed to ${bondState.name}", peer)
        emitBondState(device.address, bondState)

        if (update.pairingFailed) {
            removeConnectedDevice(device.address)
            Log.w(TAG, "Pairing ended without a bond for peer=${redactDeviceId(device.address)}")
            // The stack normally drops this link itself. Cancelling an
            // still-live link keeps the next advertiser session available, and
            // late disconnect callbacks are ignored because the tracker was
            // already cleared above.
            if (peer.linkConnected) {
                gattServer?.cancelConnection(device)
            }
        }
    }

    private fun emitConnectionState(
        deviceId: String,
        connected: Boolean,
        onDelivered: (() -> Unit)? = null,
    ) {
        val callback = bleCallback
        if (callback == null) {
            onDelivered?.invoke()
            return
        }
        callback.onConnectionStateChange(deviceId, connected) {
            onDelivered?.let { continuation -> runOnMain(continuation) }
        }
    }

    private fun emitBondState(deviceId: String, bondState: PeerBondState) {
        bleCallback?.onBondStateChange(deviceId, bondState.toPigeonBondState()) {}
    }

    private fun emitSubscriptionState(
        deviceId: String,
        characteristicId: String,
        isSubscribed: Boolean,
        name: String?,
    ) {
        bleCallback?.onCharacteristicSubscriptionChange(
            deviceId,
            characteristicId,
            isSubscribed,
            name,
        ) {}
    }

    private fun emitBleState(enabled: Boolean) {
        runOnMain { bleCallback?.onBleStateChange(enabled) {} }
    }

    private fun emitAdvertisingStatus(advertising: Boolean, error: String?) {
        bleCallback?.onAdvertisingStatusUpdate(advertising, error) {}
    }

    private fun createAdvertiseCallback(generation: Long): AdvertiseCallback =
        object : AdvertiseCallback() {
            override fun onStartFailure(errorCode: Int) {
                super.onStartFailure(errorCode)
                runOnMain {
                    if (generation != advertisingGeneration) {
                        return@runOnMain
                    }
                    advertisingStartPending = false
                    isAdvertising = false
                    advertisingRequested = false
                    activeAdvertiseCallback = null
                    val errorMessage = when (errorCode) {
                        ADVERTISE_FAILED_ALREADY_STARTED -> "Already started"
                        ADVERTISE_FAILED_DATA_TOO_LARGE -> "Data too large"
                        ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> "Feature unsupported"
                        ADVERTISE_FAILED_INTERNAL_ERROR -> "Internal error"
                        ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> "Too many advertisers"
                        else -> "Failed to start advertising: $errorCode"
                    }
                    emitAdvertisingStatus(advertising = false, error = errorMessage)
                }
            }

            override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                super.onStartSuccess(settingsInEffect)
                runOnMain {
                    if (generation != advertisingGeneration) {
                        return@runOnMain
                    }
                    advertisingStartPending = false
                    if (!advertisingRequested) {
                        // A stop raced a delayed start callback. Do not resurrect
                        // advertising for a cancelled attempt.
                        bluetoothLeAdvertiser?.stopAdvertising(this)
                        isAdvertising = false
                        activeAdvertiseCallback = null
                        return@runOnMain
                    }
                    isAdvertising = true
                    emitAdvertisingStatus(advertising = true, error = null)
                }
            }
        }

    private val gattServerCallback: BluetoothGattServerCallback =
        object : BluetoothGattServerCallback() {
            override fun onConnectionStateChange(
                device: BluetoothDevice,
                status: Int,
                newState: Int,
            ) {
                super.onConnectionStateChange(device, status, newState)
                runOnMain { handleConnectionStateChange(device, status, newState) }
            }

            override fun onMtuChanged(device: BluetoothDevice?, mtu: Int) {
                super.onMtuChanged(device, mtu)
                val peer = device ?: return
                val generation = peerSessions.currentGenerationIfConnected(peer.address) ?: return
                runOnMain {
                    if (peerSessions.isCurrentConnected(peer.address, generation)) {
                        bleCallback?.onMtuChange(peer.address, mtu.toLong()) {}
                    }
                }
            }

            override fun onCharacteristicReadRequest(
                device: BluetoothDevice,
                requestId: Int,
                offset: Int,
                characteristic: BluetoothGattCharacteristic,
            ) {
                super.onCharacteristicReadRequest(device, requestId, offset, characteristic)
                val generation = peerSessions.currentGenerationIfConnected(device.address)
                if (generation == null) {
                    gattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_FAILURE,
                        0,
                        emptyBytes,
                    )
                    return
                }

                runOnMain {
                    if (!peerSessions.isCurrentConnected(device.address, generation)) {
                        return@runOnMain
                    }
                    bleCallback?.onReadRequest(
                        deviceIdArg = device.address,
                        characteristicIdArg = characteristic.uuid.toString(),
                        offsetArg = offset.toLong(),
                        valueArg = characteristic.value,
                    ) { result ->
                        runOnMain {
                            if (!peerSessions.isCurrentConnected(device.address, generation)) {
                                return@runOnMain
                            }
                            val readResult = result.getOrNull()
                            if (readResult == null) {
                                gattServer?.sendResponse(
                                    device,
                                    requestId,
                                    BluetoothGatt.GATT_FAILURE,
                                    0,
                                    emptyBytes,
                                )
                            } else {
                                gattServer?.sendResponse(
                                    device,
                                    requestId,
                                    BluetoothGatt.GATT_SUCCESS,
                                    readResult.offset?.toInt() ?: 0,
                                    readResult.value,
                                )
                            }
                        }
                    }
                }
            }

            override fun onCharacteristicWriteRequest(
                device: BluetoothDevice,
                requestId: Int,
                characteristic: BluetoothGattCharacteristic,
                preparedWrite: Boolean,
                responseNeeded: Boolean,
                offset: Int,
                value: ByteArray,
            ) {
                super.onCharacteristicWriteRequest(
                    device,
                    requestId,
                    characteristic,
                    preparedWrite,
                    responseNeeded,
                    offset,
                    value,
                )
                val generation = peerSessions.currentGenerationIfConnected(device.address)
                if (generation == null) {
                    if (responseNeeded) {
                        gattServer?.sendResponse(
                            device,
                            requestId,
                            BluetoothGatt.GATT_FAILURE,
                            0,
                            emptyBytes,
                        )
                    }
                    return
                }

                runOnMain {
                    if (!peerSessions.isCurrentConnected(device.address, generation)) {
                        return@runOnMain
                    }
                    bleCallback?.onWriteRequest(
                        deviceIdArg = device.address,
                        characteristicIdArg = characteristic.uuid.toString(),
                        offsetArg = offset.toLong(),
                        valueArg = value,
                    ) { result ->
                        runOnMain {
                            if (!responseNeeded ||
                                !peerSessions.isCurrentConnected(device.address, generation)
                            ) {
                                return@runOnMain
                            }
                            val writeResult = result.getOrNull()
                            gattServer?.sendResponse(
                                device,
                                requestId,
                                writeResult?.status?.toInt() ?: BluetoothGatt.GATT_SUCCESS,
                                writeResult?.offset?.toInt() ?: 0,
                                writeResult?.value ?: emptyBytes,
                            )
                        }
                    }
                }
            }

            override fun onServiceAdded(status: Int, service: BluetoothGattService) {
                super.onServiceAdded(status, service)
                val error = if (status == BluetoothGatt.GATT_SUCCESS) null else "Adding service failed"
                runOnMain { bleCallback?.onServiceAdded(service.uuid.toString(), error) {} }
            }

            override fun onDescriptorReadRequest(
                device: BluetoothDevice,
                requestId: Int,
                offset: Int,
                descriptor: BluetoothGattDescriptor,
            ) {
                super.onDescriptorReadRequest(device, requestId, offset, descriptor)
                val generation = peerSessions.currentGenerationIfConnected(device.address)
                runOnMain {
                    if (generation == null ||
                        !peerSessions.isCurrentConnected(device.address, generation)
                    ) {
                        gattServer?.sendResponse(
                            device,
                            requestId,
                            BluetoothGatt.GATT_FAILURE,
                            0,
                            emptyBytes,
                        )
                        return@runOnMain
                    }
                    val value = descriptor.getCacheValue()
                    gattServer?.sendResponse(
                        device,
                        requestId,
                        if (value == null) BluetoothGatt.GATT_FAILURE else BluetoothGatt.GATT_SUCCESS,
                        0,
                        value ?: emptyBytes,
                    )
                }
            }

            override fun onDescriptorWriteRequest(
                device: BluetoothDevice?,
                requestId: Int,
                descriptor: BluetoothGattDescriptor,
                preparedWrite: Boolean,
                responseNeeded: Boolean,
                offset: Int,
                value: ByteArray?,
            ) {
                super.onDescriptorWriteRequest(
                    device,
                    requestId,
                    descriptor,
                    preparedWrite,
                    responseNeeded,
                    offset,
                    value,
                )
                val peer = device ?: return
                val generation = peerSessions.currentGenerationIfConnected(peer.address)
                runOnMain {
                    if (generation == null ||
                        !peerSessions.isCurrentConnected(peer.address, generation)
                    ) {
                        if (responseNeeded) {
                            gattServer?.sendResponse(
                                peer,
                                requestId,
                                BluetoothGatt.GATT_FAILURE,
                                0,
                                emptyBytes,
                            )
                        }
                        return@runOnMain
                    }

                    descriptor.setValue(value)
                    var subscriptionEvent: Pair<String, Boolean>? = null
                    if (descriptor.uuid.toString().lowercase() == descriptorCCUUID) {
                        val isSubscribed =
                            BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE.contentEquals(value) ||
                                    BluetoothGattDescriptor.ENABLE_INDICATION_VALUE.contentEquals(value)
                        val characteristicId = descriptor.characteristic.uuid.toString()
                        val update = peerSessions.onSubscriptionChanged(
                            address = peer.address,
                            characteristicId = characteristicId,
                            isSubscribed = isSubscribed,
                        )
                        if (update.accepted && update.changed) {
                            val snapshot = update.snapshot
                            if (snapshot != null) {
                                logPeer(
                                    "CCCD subscription changed for characteristic=$characteristicId " +
                                            "subscribed=$isSubscribed",
                                    snapshot,
                                )
                            }
                            subscriptionEvent = characteristicId to isSubscribed
                        }
                    }

                    if (responseNeeded) {
                        gattServer?.sendResponse(
                            peer,
                            requestId,
                            BluetoothGatt.GATT_SUCCESS,
                            offset,
                            value ?: emptyBytes,
                        )
                    }
                    // Report subscription only after accepting the CCCD write.
                    // This keeps the Dart readiness state from racing a failed
                    // descriptor response.
                    subscriptionEvent?.let { (characteristicId, isSubscribed) ->
                        emitSubscriptionState(
                            deviceId = peer.address,
                            characteristicId = characteristicId,
                            isSubscribed = isSubscribed,
                            name = peer.name,
                        )
                    }
                }
            }

            override fun onNotificationSent(device: BluetoothDevice?, status: Int) {
                super.onNotificationSent(device, status)
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    Log.e(
                        TAG,
                        "Notification failed for peer=${redactDeviceId(device?.address)} status=$status",
                    )
                }
            }
        }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        unregisterBroadcastReceiver()
        advertisingRequested = false
        advertisingStartPending = false
        advertisingGeneration++
        val callback = activeAdvertiseCallback
        activeAdvertiseCallback = null
        try {
            callback?.let { bluetoothLeAdvertiser?.stopAdvertising(it) }
        } catch (_: IllegalStateException) {
            // Bluetooth may already be off during process teardown.
        }
        gattServer?.close()
        gattServer = null
        synchronized(bluetoothDevicesMap) { bluetoothDevicesMap.clear() }
        peerSessions.clear()
        isAdvertising = false
        activity = null
        bleCallback = null
        applicationContext = null
        handler = null
    }

    private fun registerBroadcastReceiver() {
        val context = applicationContext ?: return
        if (receiverRegistered) return
        val intentFilter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED).apply {
            addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(broadcastReceiver, intentFilter, RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(broadcastReceiver, intentFilter)
        }
        receiverRegistered = true
    }

    private fun unregisterBroadcastReceiver() {
        val context = applicationContext ?: return
        if (!receiverRegistered) return
        try {
            context.unregisterReceiver(broadcastReceiver)
        } catch (_: IllegalArgumentException) {
            // The process can tear down an Android receiver before Flutter has
            // delivered the corresponding detach callback.
        } finally {
            receiverRegistered = false
        }
    }

    private val broadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                BluetoothAdapter.ACTION_STATE_CHANGED -> {
                    if (!intent.hasExtra(BluetoothAdapter.EXTRA_STATE)) return
                    when (intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)) {
                        BluetoothAdapter.STATE_OFF -> emitBleState(enabled = false)
                        BluetoothAdapter.STATE_ON -> emitBleState(enabled = true)
                    }
                }

                BluetoothDevice.ACTION_BOND_STATE_CHANGED -> {
                    val device = intent.getBluetoothDevice() ?: return
                    if (!intent.hasExtra(BluetoothDevice.EXTRA_BOND_STATE)) return
                    val state = intent.getIntExtra(
                        BluetoothDevice.EXTRA_BOND_STATE,
                        BluetoothDevice.ERROR,
                    )
                    runOnMain { handleBondStateChange(device, state.toPeerBondState()) }
                }
            }
        }
    }

    override fun askBlePermission(): Boolean {
        val permissionsList = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_ADMIN,
                Manifest.permission.BLUETOOTH,
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_ADVERTISE,
            )
        } else {
            arrayOf(
                Manifest.permission.BLUETOOTH_ADMIN,
                Manifest.permission.BLUETOOTH,
            )
        }
        val havePermission = activity?.havePermission(permissionsList) ?: false
        if (havePermission) return true
        activity?.let {
            ActivityCompat.requestPermissions(it, permissionsList, requestCodeBluetoothPermission)
        }
        return false
    }

    private fun runOnMain(action: () -> Unit) {
        val mainHandler = handler ?: return
        if (Looper.myLooper() == mainHandler.looper) {
            action()
        } else {
            mainHandler.post(action)
        }
    }

    private fun logPeer(message: String, peer: PeerSnapshot) {
        Log.d(
            TAG,
            "$message peer=${redactDeviceId(peer.address)} generation=${peer.generation} " +
                    "link=${peer.linkConnected} bond=${peer.bondState} " +
                    "subscriptions=${peer.subscriptions.size}",
        )
    }

    private fun redactDeviceId(deviceId: String?): String {
        if (deviceId.isNullOrBlank()) return "unknown"
        val compact = deviceId.replace(":", "")
        return if (compact.length <= 4) "…$compact" else "…${compact.takeLast(4)}"
    }
}

private fun Int.toPeerBondState(): PeerBondState {
    return when (this) {
        BluetoothDevice.BOND_BONDING -> PeerBondState.BONDING
        BluetoothDevice.BOND_BONDED -> PeerBondState.BONDED
        else -> PeerBondState.NONE
    }
}

private fun PeerBondState.toPigeonBondState(): BondState {
    return when (this) {
        PeerBondState.BONDING -> BondState.BONDING
        PeerBondState.BONDED -> BondState.BONDED
        PeerBondState.NONE -> BondState.NONE
    }
}

private fun Intent.getBluetoothDevice(): BluetoothDevice? {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
    } else {
        @Suppress("DEPRECATION")
        getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
    }
}
