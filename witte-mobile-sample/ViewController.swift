import UIKit
import TapkeyMobileLib
import witte_mobile_library

class ViewController: UIViewController {
    private var tokenProvider: TokenProvider!
    private var tapkeyKeyManager: TKMKeyManager?
    private var tapkeyUserManager: TKMUserManager?
    private var tapkeyBleLockScanner: TKMBleLockScanner?
    private var tapkeyBleLockCommunicator: TKMBleLockCommunicator?
    private var tapkeyCommandExecutionFacade: TKMCommandExecutionFacade?
    private var tapkeyNotificationManager: TKMNotificationManager?
    private var tapkeyKeys: [TKMKeyDetails] = []

    private var tapkeyStartForegroundScanRegistration: TKMObserverRegistration?
    private var tapkeyKeyObserverRegistration: TKMObserverRegistration?
    private var tapkeyBluetoothStateObserverRegistration: TKMObserverRegistration?

    @IBOutlet weak var labelCustomerId: UILabel!
    @IBOutlet weak var labelSubscriptionKey: UILabel!
    @IBOutlet weak var labelSdkKey: UILabel!
    @IBOutlet weak var labelUserId: UILabel!
    @IBOutlet weak var labelKeys: UILabel!
    @IBOutlet weak var buttonLogin: UIButton!
    @IBOutlet weak var buttonLogout: UIButton!
    @IBOutlet weak var buttonTriggerLock: UIButton!
    @IBOutlet weak var buttonReloadLocalKeys: UIButton!
    @IBOutlet weak var textFieldBoxId: UITextField!

    @IBAction func actionLogin(_ sender: Any) {
        login()
    }

    @IBAction func actionLogout(_ sender: Any) {
        logout()
    }

    @IBAction func actionTriggerLock(_ sender: Any) {
        triggerLock()
    }

    @IBAction func actionBoxIdChanged(_ sender: Any) {
    }

    @IBAction func actionReloadLocalKeys(_ sender: Any) {
        queryLocalKeys()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let app: AppDelegate = UIApplication.shared.delegate as! AppDelegate
        tokenProvider = app.tokenProvider

        let tapkeyServiceFactory = app.tapkeyServiceFactory!
        tapkeyKeyManager = tapkeyServiceFactory.keyManager
        tapkeyUserManager = tapkeyServiceFactory.userManager
        tapkeyBleLockScanner = tapkeyServiceFactory.bleLockScanner
        tapkeyBleLockCommunicator = tapkeyServiceFactory.bleLockCommunicator
        tapkeyCommandExecutionFacade = tapkeyServiceFactory.commandExecutionFacade
        tapkeyNotificationManager = tapkeyServiceFactory.notificationManager

        // Update label content
        labelCustomerId.text = String(DemoBackendAccessor.FlinkeyCustomerId)
        labelSubscriptionKey.text = DemoBackendAccessor.FlinkeyApiKey
        labelSdkKey.text = DemoBackendAccessor.FlinkeySdkKey
        labelUserId.text = String(DemoBackendAccessor.FlinkeyUserId)

        // Initially disable triggerLock button
        updateButtonStates()

        // Hide keyboard on tap
        view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
    }

    /**
     Checks if a user is logged in to the Tapkey Mobile Library.
     - Returns: true is a user is logged in
     */
    private func isUserLoggedIn() -> Bool {
        var isLoggedIn = false

        let userIds = tapkeyUserManager?.users
        if (nil != userIds && 1 == userIds?.count) {
            isLoggedIn = true
        }

        return isLoggedIn
    }

    /**
     Updates UI controls according to the state of the users login.
     */
    private func updateButtonStates() {
        if !isUserLoggedIn() {
            buttonLogin.isEnabled = true
            buttonLogout.isEnabled = false
            buttonTriggerLock.isEnabled = false
            buttonReloadLocalKeys.isEnabled = false
            labelKeys.text = ""
        } else {
            buttonLogin.isEnabled = false
            buttonLogout.isEnabled = true;
            buttonTriggerLock.isEnabled = true
            buttonReloadLocalKeys.isEnabled = true
        }
    }

    /**
     Authenticates a user with the Tapkey Mobile Library.
     */
    private func login() {
        if isUserLoggedIn() {
            return
        }

        tokenProvider
                .accessToken()
                .continueAsyncOnUi { accessToken -> TKMPromise<String> in
                    self.tapkeyUserManager!.logInAsync(accessToken: accessToken!, cancellationToken: TKMCancellationTokens.None)
                }
                .continueOnUi { (userId: String?) -> Void in
                    // Update UI
                    self.updateButtonStates()

                    // Start scanning for flinkey boxes
                    self.startScanning()

                    // Synchronize digital keys
                    self.tapkeyNotificationManager!
                            .pollForNotificationsAsync(cancellationToken: TKMCancellationTokens.None)
                            .continueOnUi({ Void in
                                self.queryLocalKeys()
                                return nil
                            })
                            .catchOnUi({ (error: TKMAsyncError) -> Void in
                            })
                            .conclude();
                }
                .catchOnUi { (error: TKMAsyncError?) -> Void in
                    print("Login failed. \(String(describing: error?.localizedDescription))")
                }
                .conclude()

    }

    /**
     Logs the user out from the Tapkey Mobile Library.
     */
    private func logout() {
        if !isUserLoggedIn() {
            updateButtonStates()
            return
        }

        let userId = tapkeyUserManager!.users[0]
        tapkeyUserManager!
                .logOutAsync(userId: userId, cancellationToken: TKMCancellationTokens.None)
                .finallyOnUi {
                    self.updateButtonStates()
                }
                .conclude()
    }

    /**
     Starts scanning for flinkey boxes.
     */
    private func startScanning() {
        if (nil == tapkeyStartForegroundScanRegistration) {
            tapkeyStartForegroundScanRegistration = tapkeyBleLockScanner?.startForegroundScan()
        }
    }

    /**
     Stops scanning for flinkey boxes.
     */
    private func stopScanning() {
        if (nil != tapkeyStartForegroundScanRegistration) {
            tapkeyStartForegroundScanRegistration?.close()
            tapkeyStartForegroundScanRegistration = nil
        }
    }

    /**
     Checks locally available digital keys.
     */
    private func queryLocalKeys() {
        if !isUserLoggedIn() {
            return
        }

        let userId = tapkeyUserManager!.users[0]
        tapkeyKeyManager!.queryLocalKeysAsync(userId: userId, cancellationToken: TKMCancellationTokens.None)
                .continueOnUi { (keys: [TKMKeyDetails]?) -> Void in
                    self.tapkeyKeys = keys ?? [];

                    var sb = ""
                    for key in self.tapkeyKeys {
                        let grant = key.grant
                        if (nil != grant) {
                            let physicalLockId = grant?.getBoundLock()?.getPhysicalLockId();
                            let boxId = WDBoxIdConverter().toBoxId(withPhysicalLockId: physicalLockId!)
                            let grantValidFrom = grant?.getValidFrom()?.toDate() ?? nil
                            let grantValidBefore = grant?.getValidBefore()?.toDate() ?? nil
                            let keyValidBefore = key.validBefore

                            sb.append("• \(boxId)\n")
                            sb.append(" grant starts: \(self.toIsoString(date: grantValidFrom))\n")
                            if (nil != grantValidBefore) {
                                sb.append(" grant ends: \(self.toIsoString(date: grantValidBefore))\n")
                            } else {
                                sb.append(" grant ends: unlimited\n")
                            }

                            sb.append(" valid before: \(self.toIsoString(date: keyValidBefore))\n")
                        }
                    }

                    self.labelKeys.text = sb
                }
                .catchOnUi({ (error: TKMAsyncError) -> Void? in
                    print("Query local keys failed.")
                    return nil
                })
                .conclude()

    }

    /**
     Converts a date to an ISO 8601 string representation.
     - Parameter date: Date
     - Returns: ISO 8601 string
     */
    open func toIsoString(date: Date?) -> String {
        var str = ""

        if (date != nil) {
            let formatter = ISO8601DateFormatter()
            str = formatter.string(from: date!)
        }

        return str;
    }

    /**
     Opens of closes (triggers) a flinkey box.
     */
    private func triggerLock() {
        // User needs to be logged in
        if (!isUserLoggedIn()) {
            let alert = UIAlertController(title: nil, message: "Please login first", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            present(alert, animated: true)
            return
        }

        // Get box id
        let boxId = textFieldBoxId.text
        if (nil == boxId || boxId!.isEmpty) {
            let alert = UIAlertController(title: nil, message: "Please enter your box ID", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            present(alert, animated: true)
            return;
        }

        // Convert box id to physical lock id
        let converter = WDBoxIdConverter()
        let physicalLockId = converter.toPhysicalLockId(withBoxId: boxId!);
        if (physicalLockId.isEmpty) {
            let alert = UIAlertController(title: nil, message: "\(boxId!) is not a valid box Id.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            present(alert, animated: true)
            return;
        }

        // Check if box is in reach
        if (!tapkeyBleLockScanner!.isLockNearby(physicalLockId: physicalLockId)) {
            let alert = UIAlertController(title: nil, message: "The box \(boxId!) is not in reach.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            present(alert, animated: true)
            return;
        }

        // 60s timeout
        let timeoutMs: Int32 = 60 * 1000
        let timeout = TKMCancellationTokens.fromTimeout(timeoutMs: timeoutMs)
        let bluetoothAddress = tapkeyBleLockScanner!.getLock(physicalLockId: physicalLockId)?.bluetoothAddress
        if (nil != bluetoothAddress) {
            tapkeyBleLockCommunicator!
                    .executeCommandAsync(
                            bluetoothAddress: bluetoothAddress!,
                            physicalLockId: physicalLockId,
                            commandFunc: { tlcpConnection -> TKMPromise<TKMCommandResult> in
                                let triggerLockCommand = TKMDefaultTriggerLockCommandBuilder().build()
                            
                                // Pass the TLCP connection to the command execution facade
                                return self.tapkeyCommandExecutionFacade!.executeStandardCommandAsync(tlcpConnection, command: triggerLockCommand, cancellationToken: timeout)
                            },
                            cancellationToken: timeout)
                    .continueOnUi { (commandResult: TKMCommandResult?) -> Bool? in
                        var success = false

                        // The TKMCommandResultCode indicates if triggerLockAsync completed successfully
                        // or if an error occurred during the execution of the command.
                        // https://developers.tapkey.io/mobile/ios/reference/TapkeyMobileLib/latest/Classes/TKMCommandResult.html
                        let commandResultCode: TKMCommandResult.TKMCommandResultCode = commandResult?.code ?? TKMCommandResult.TKMCommandResultCode.technicalError

                        switch commandResultCode {
                        case TKMCommandResult.TKMCommandResultCode.ok:
                            success = true
                            let responseData = commandResult?.responseData
                            if (nil != responseData) {
                                let bytes = responseData! as! IOSByteArray
                                let data = bytes.toNSData()
                                let boxFeedback = WDBoxFeedback(responseData: data!)

                                if (WDBoxState.unlocked == boxFeedback.boxState) {
                                    print("Box has been opened")
                                } else if (WDBoxState.locked == boxFeedback.boxState) {
                                    print("Box has been closed")
                                } else if (WDBoxState.drawerOpen == boxFeedback.boxState) {
                                    print("The drawer of the Box is open")
                                }
                            }
                        case TKMCommandResult.TKMCommandResultCode.lockCommunicationError:
                            print("A transport-level error occurred when communicating with the locking device")
                        case TKMCommandResult.TKMCommandResultCode.lockDateTimeInvalid:
                            print("Lock date/time are invalid.")
                        case TKMCommandResult.TKMCommandResultCode.serverCommunicationError:
                            print("An error occurred while trying to communicate with the Tapkey Trust Service (e.g. due to bad internet connection).")
                        case TKMCommandResult.TKMCommandResultCode.technicalError:
                            print("Some unspecific technical error has occurred.")
                        case TKMCommandResult.TKMCommandResultCode.unauthorized:
                            print("Communication with the security backend succeeded but the user is not authorized for the given command on this locking device.")
                        case TKMCommandResult.TKMCommandResultCode.userSpecificError:
                            // If there is a userSpecificError we need to have look at the list
                            // of TKMUserCommandResults in order to determine what exactly caused the error
                            // https://developers.tapkey.io/mobile/ios/reference/TapkeyMobileLib/latest/Classes/TKMCommandResult/TKMUserCommandResult.html
                            let userCommandResults = commandResult?.userCommandResults
                            for userCommandResult in userCommandResults! {
                                print("triggerLockAsync failed with UserSpecificError and UserCommandResultCode \(userCommandResult.code)");
                                print(userCommandResult.code)
                            }
                        default:
                            print("triggerLock failed with error")
                        }
                        return success
                    }
                    .catchOnUi { (error: TKMAsyncError) -> Bool? in
                        print("triggerLock failed")
                        return false
                    }
                    .conclude()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        if (nil == tapkeyKeyObserverRegistration) {
            tapkeyKeyObserverRegistration = tapkeyKeyManager?.keyUpdateObservable.addObserver({ _ in
                self.queryLocalKeys()
            })
        }

        if (nil == tapkeyBluetoothStateObserverRegistration) {
            tapkeyBluetoothStateObserverRegistration = tapkeyBleLockScanner?.observable.addObserver({ _ in
                print("flinkey box availability changed")
            })
        }

        startScanning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        if (nil != tapkeyKeyObserverRegistration) {
            tapkeyKeyObserverRegistration!.close();
            tapkeyKeyObserverRegistration = nil;
        }

        if (nil != tapkeyBluetoothStateObserverRegistration) {
            tapkeyBluetoothStateObserverRegistration!.close();
            tapkeyBluetoothStateObserverRegistration = nil;
        }

        stopScanning()
    }
}
