# BLETransfer

### 1. How to build
 - Open the project file `BLETransfer.xcodeproj` using `Xcode`
 - Connect both iPhones to the computer via cable and make sure `Developer Mode` is enabled on each device ([Follow this intruction](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device))
 - Select the target device to run the app by choosing it from the top bar.
  ![image](https://github.com/nwanvu93/BLETransfer/blob/main/assets/select-device.png?raw=true)
 - press `Command + R` to build and run.


### 2. Authentication protocol implementation
 - First step: using [swift-protobuf](https://github.com/apple/swift-protobuf/tree/main) to generate Swift code from the provided `.proto` files
 - Copy the generated Swift files to the project
 - Import the `swift-protobuf` library to the project
 - Use Swift files in code:
    ```
    // encode
    let nonceMessage = Com_Cramium_Sdk_NonceRequest.with {
        $0.nonce = ...
    }
    let data = try? nonceMessage.serializedData()

    // decode
    let nonceMessage = try? Com_Cramium_Sdk_NonceRequest(serializedBytes: data)
    let nonce = nonceMessage.nonce
    ```

### 3. BLE transfer
  - Transferring files over BLE is constrained by the data packet bandwidth. Data Length Extension (DLE) can increase this bandwidth, but its availability depends on the BLE version and device support.

### 4. Limitations
- In the demo video, I tested on two iPhones running iOS 18 with DLE support. The maximum bandwidth per data packet that can be sent is 512 bytes.
- Transferring a 1MB file takes about 2 minutes and 13 seconds.

### 5. Demo Video
[https://drive.google.com/file/d/1RQbUlUsf8GCu4hX7eJFDiLv4ANbYpB7V/view?usp=sharing](https://drive.google.com/file/d/1RQbUlUsf8GCu4hX7eJFDiLv4ANbYpB7V/view?usp=sharing)
