import TapkeyMobileLib
import UIKit
import witte_mobile_library

/**
 A view controller that manages the main user interface of the app.
 */
class ViewController: UIViewController {
    // TokenProvider instance used for authentication
    private var tokenProvider: TokenProvider!
    
    // KeyManager instance from Tapkey used for managing keys
    private var tapkeyKeyManager: TKMKeyManager?
    
    // UserManager instance from Tapkey used for managing users
    private var tapkeyUserManager: TKMUserManager?
    
    // BleLockScanner instance from Tapkey used for scanning BLE locks
    private var tapkeyBleLockScanner: TKMBleLockScanner?
    
    // BleLockCommunicator instance from Tapkey used for communicating with BLE locks
    private var tapkeyBleLockCommunicator: TKMBleLockCommunicator?
    
    // CommandExecutionFacade instance from Tapkey used for executing commands
    private var tapkeyCommandExecutionFacade: TKMCommandExecutionFacade?
    
    // NotificationManager instance from Tapkey used for managing notifications
    private var tapkeyNotificationManager: TKMNotificationManager?
    
    // Array of KeyDetails from Tapkey representing the keys
    private var tapkeyKeys: [TKMKeyDetails] = []
    
    // ObserverRegistrations from Tapkey used for observing certain events
    private var tapkeyStartForegroundScanRegistration: TKMObserverRegistration?
    private var tapkeyKeyObserverRegistration: TKMObserverRegistration?
    private var tapkeyBluetoothStateObserverRegistration: TKMObserverRegistration?
    
    // UI elements
    @IBOutlet weak var labelCustomerId: UILabel! // Label for displaying Customer ID
    @IBOutlet weak var labelSubscriptionKey: UILabel! // Label for displaying Subscription Key
    @IBOutlet weak var labelSdkKey: UILabel! // Label for displaying SDK Key
    @IBOutlet weak var labelUserId: UILabel! // Label for displaying User ID
    @IBOutlet weak var labelKeys: UILabel! // Label for displaying Keys
    @IBOutlet weak var buttonLogin: UIButton! // Button for Login action
    @IBOutlet weak var buttonLogout: UIButton! // Button for Logout action
    @IBOutlet weak var buttonTriggerLock: UIButton! // Button for Trigger Lock action
    @IBOutlet weak var buttonUnlock: UIButton! // Button for Unlock action
    @IBOutlet weak var buttonLock: UIButton! // Button for Lock action
    @IBOutlet weak var buttonReloadLocalKeys: UIButton! // Button for Reload Local Keys action
    @IBOutlet weak var textFieldBoxId: UITextField! // TextField for inputting Box ID
    
    /**
     Performs the login action when the login button is tapped.
     
     - Parameter sender: The object that triggered the action.
     */
    @IBAction func actionLogin(_ sender: Any) {
        login()
    }
    
    /**
     Performs the logout action.
     
     - Parameter sender: The object that triggered the action.
     */
    @IBAction func actionLogout(_ sender: Any) {
        logout()
    }
    
    /**
     Performs the trigger lock action.
     
     - Parameter sender: The object that triggered the action.
     */
    @IBAction func actionTriggerLock(_ sender: Any) {
        executeBoxCommand(boxCommandData: nil)
    }
    
    /**
     Performs the action when the unlock button is tapped.
     
     - Parameter sender: The object that triggered the action.
     */
    @IBAction func actionUnlock(_ sender: Any) {
        let data: Data = WDBoxCommandBuilder.buildUnlockCarUnlockBox()
        executeBoxCommand(boxCommandData: data.base64EncodedString())
    }
    
    /**
     Performs the action when the lock button is pressed.
     
     - Parameter sender: The object that triggered the action.
     */
    @IBAction func actionLock(_ sender: Any) {
        let data: Data = WDBoxCommandBuilder.buildLockCarLockBox()
        executeBoxCommand(boxCommandData: data.base64EncodedString())
    }
    
    @IBAction func actionBoxIdChanged(_ sender: Any) {
    }
    
    /**
     Reloads the local keys.
     
     - Parameter sender: The object that triggered the action.
     */
    @IBAction func actionReloadLocalKeys(_ sender: Any) {
        queryLocalKeys()
    }
    
    /**
     The method called after the controller's view is loaded into memory.
     */
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
        
        textFieldBoxId.text = "C3-49-EE-54"
        
        // Hide keyboard on tap
        view.addGestureRecognizer(
            UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
    }
    
    /**
     Checks if a user is logged in to the Tapkey Mobile Library.
     - Returns: true is a user is logged in
     */
    private func isUserLoggedIn() -> Bool {
        var isLoggedIn = false
        
        let userIds = tapkeyUserManager?.users
        if nil != userIds && 1 == userIds?.count {
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
            buttonLock.isEnabled = false
            buttonUnlock.isEnabled = false
            buttonReloadLocalKeys.isEnabled = false
            labelKeys.text = ""
        } else {
            buttonLogin.isEnabled = false
            buttonLogout.isEnabled = true
            buttonTriggerLock.isEnabled = true
            buttonLock.isEnabled = true
            buttonUnlock.isEnabled = true
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
                self.tapkeyUserManager!.logInAsync(
                    accessToken: accessToken!, cancellationToken: TKMCancellationTokens.None)
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
                    .conclude()
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
        if nil == tapkeyStartForegroundScanRegistration {
            tapkeyStartForegroundScanRegistration = tapkeyBleLockScanner?.startForegroundScan()
        }
    }
    
    /**
     Stops scanning for flinkey boxes.
     */
    private func stopScanning() {
        if nil != tapkeyStartForegroundScanRegistration {
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
        let keys = tapkeyKeyManager!.getLocalKeys(userId: userId)
        
        self.tapkeyKeys = keys
        
        var sb = ""
        for key in self.tapkeyKeys {
            let grant = key.grant
            let physicalLockId = grant.boundLock.physicalLockId
            let boxId = WDBoxIdConverter().toBoxId(withPhysicalLockId: physicalLockId)
            let grantValidFrom = grant.validFrom ?? nil
            let grantValidBefore = grant.validBefore ?? nil
            let keyValidBefore = key.validBefore
            
            sb.append("• \(boxId)\n")
            sb.append(" grant starts: \(self.toIsoString(date: grantValidFrom))\n")
            if nil != grantValidBefore {
                sb.append(" grant ends: \(self.toIsoString(date: grantValidBefore))\n")
            } else {
                sb.append(" grant ends: unlimited\n")
            }
            
            sb.append(" valid before: \(self.toIsoString(date: keyValidBefore))\n")
        }
        
        self.labelKeys.text = sb
    }
    
    /**
     Converts a date to an ISO 8601 string representation.
     - Parameter date: Date
     - Returns: ISO 8601 string
     */
    open func toIsoString(date: Date?) -> String {
        var str = ""
        
        if date != nil {
            let formatter = ISO8601DateFormatter()
            str = formatter.string(from: date!)
        }
        
        return str
    }
    
    /**
     Executes a box command with the given data.
     
     - Parameters:
     - boxCommandData: The data for the box command.
     */
    private func executeBoxCommand(boxCommandData: String?) {
        // User needs to be logged in
        if !isUserLoggedIn() {
            let alert = UIAlertController(
                title: nil, message: "Please login first", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            present(alert, animated: true)
            return
        }
        
        // Get box id
        let boxId = textFieldBoxId.text
        if nil == boxId || boxId!.isEmpty {
            let alert = UIAlertController(
                title: nil, message: "Please enter your box ID", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            present(alert, animated: true)
            return
        }
        
        // Convert box id to physical lock id
        let converter = WDBoxIdConverter()
        let physicalLockId = converter.toPhysicalLockId(withBoxId: boxId!)
        if physicalLockId.isEmpty {
            let alert = UIAlertController(
                title: nil, message: "\(boxId!) is not a valid box Id.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            present(alert, animated: true)
            return
        }
        
        // Check if box is in reach
        if !tapkeyBleLockScanner!.isLockNearby(physicalLockId: physicalLockId) {
            let alert = UIAlertController(
                title: nil, message: "The box \(boxId!) is not in reach.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            present(alert, animated: true)
            return
        }
        
        // 60s timeout
        let timeoutMs: Int32 = 60 * 1000
        let timeout = TKMCancellationTokens.fromTimeout(timeoutMs: timeoutMs)
        let bluetoothAddress = tapkeyBleLockScanner!.getLock(physicalLockId: physicalLockId)?.peripheralId
        
        if nil != bluetoothAddress {
            let commandExecutionFacade: TKMCommandExecutionFacade = self.tapkeyCommandExecutionFacade!
            
            // Show loading indicator
            let loadingIndicator = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.large)
            loadingIndicator.frame = view.bounds
            loadingIndicator.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.5)
            loadingIndicator.center = view.center
            loadingIndicator.startAnimating()
            view.addSubview(loadingIndicator)
            
            // Execute command
            tapkeyBleLockCommunicator!
                .executeCommandAsync(
                    peripheralId: bluetoothAddress!,
                    physicalLockId: physicalLockId,
                    commandFunc: { tlcpConnection -> TKMPromise<TKMCommandResult> in
                        if let boxCommandData = boxCommandData {
                            let triggerLockCommand = TKMDefaultTriggerLockCommandBuilder()
                                .setCustomCommandData(Data(base64Encoded: boxCommandData))
                                .build()
                            
                            // Pass the TLCP connection to the command execution facade
                            return commandExecutionFacade.executeStandardCommandAsync(
                                tlcpConnection, command: triggerLockCommand, cancellationToken: timeout)
                        } else {
                            let triggerLockCommand = TKMDefaultTriggerLockCommandBuilder()
                                .build()
                            
                            // Pass the TLCP connection to the command execution facade
                            return commandExecutionFacade.executeStandardCommandAsync(
                                tlcpConnection, command: triggerLockCommand, cancellationToken: timeout)
                        }
                    },
                    cancellationToken: timeout
                )
                .continueOnUi { (commandResult: TKMCommandResult?) -> Bool? in
                    var success = false
                    
                    // The TKMCommandResultCode indicates if triggerLockAsync completed successfully
                    // or if an error occurred during the execution of the command.
                    // https://developers.tapkey.io/mobile/ios/reference/TapkeyMobileLib/latest/Classes/TKMCommandResult.html
                    let commandResultCode: TKMCommandResult.TKMCommandResultCode =
                    commandResult?.code ?? TKMCommandResult.TKMCommandResultCode.technicalError
                    
                    switch commandResultCode {
                    case TKMCommandResult.TKMCommandResultCode.ok:
                        success = true
                        let responseData = commandResult?.responseData
                        if nil != responseData {
                            let bytes = responseData! as! IOSByteArray
                            let data = bytes.toNSData()
                            
                            // the legacy flinkey box v2.4 returns a 10 byte response
                            // The same is true for the recent flinkey box 3.3 (aka flinkey BLE) when used without box commands
                            if 10 == bytes.length() {
                                let boxFeedback = WDBoxFeedback(responseData: data!)
                                
                                if WDBoxState.unlocked == boxFeedback.boxState {
                                    print("Box has been unlocked")
                                } else if WDBoxState.locked == boxFeedback.boxState {
                                    print("Box has been locked")
                                } else if WDBoxState.drawerOpen == boxFeedback.boxState {
                                    print("The drawer of the Box is open")
                                }
                            } else {
                                // When used with box commands the flinkey box 3.3 returns a response that is less or more
                                // than 10 bytes but never exactly 10 bytes.
                                var bf: WDBoxFeedbackV3? = WDBoxFeedbackV3()
                                let success = WDBoxFeedbackV3Parser.parseData(data, boxFeedback: &bf)
                                
                                if success {
                                    if bf!.drawerState {
                                        print("The drawer of the Box is open")
                                    } else if bf!.drawerAccessibility {
                                        print("Box has been unlocked")
                                    } else {
                                        print("Box has been locked")
                                    }
                                }
                            }
                        }
                    case TKMCommandResult.TKMCommandResultCode.lockCommunicationError:
                        print("A transport-level error occurred when communicating with the locking device")
                    case TKMCommandResult.TKMCommandResultCode.lockDateTimeInvalid:
                        print("Lock date/time are invalid.")
                    case TKMCommandResult.TKMCommandResultCode.serverCommunicationError:
                        print(
                            "An error occurred while trying to communicate with the Tapkey Trust Service (e.g. due to bad internet connection)."
                        )
                    case TKMCommandResult.TKMCommandResultCode.technicalError:
                        print("Some unspecific technical error has occurred.")
                    case TKMCommandResult.TKMCommandResultCode.unauthorized:
                        print(
                            "Communication with the security backend succeeded but the user is not authorized for the given command on this locking device."
                        )
                    case TKMCommandResult.TKMCommandResultCode.userSpecificError:
                        // If there is a userSpecificError we need to have look at the list
                        // of TKMUserCommandResults in order to determine what exactly caused the error
                        // https://developers.tapkey.io/mobile/ios/reference/TapkeyMobileLib/latest/Classes/TKMCommandResult/TKMUserCommandResult.html
                        let userCommandResults = commandResult?.userCommandResults
                        for userCommandResult in userCommandResults! {
                            print(
                                "triggerLockAsync failed with UserSpecificError and UserCommandResultCode \(userCommandResult.code)"
                            )
                            print(userCommandResult.code)
                        }
                    default:
                        print("triggerLock failed with error")
                    }
                    return success
                }
                .finallyOnUi {
                    // Hide loading indicator
                    loadingIndicator.stopAnimating()
                    loadingIndicator.removeFromSuperview()
                }
                .catchOnUi { (error: TKMAsyncError) -> Bool? in
                    print("triggerLock failed")
                    return false
                }
                .conclude()
        }
    }
    
    /**
     This method is called just before the view controller's view is about to be added to the view hierarchy.
     
     - Parameter animated: A Boolean value indicating whether the transition to the new view controller is animated.
     */
    override func viewWillAppear(_ animated: Bool) {
        if nil == tapkeyKeyObserverRegistration {
            tapkeyKeyObserverRegistration = tapkeyKeyManager?.keyUpdateObservable.addObserver({ _ in
                self.queryLocalKeys()
            })
        }
        
        if nil == tapkeyBluetoothStateObserverRegistration {
            tapkeyBluetoothStateObserverRegistration = tapkeyBleLockScanner?.observable.addObserver({ _ in
                print("flinkey box availability changed")
            })
        }
        
        startScanning()
    }
    
    /**
     This method is called when the view is about to disappear from the screen.
     - Parameter animated: A Boolean value indicating whether the disappearance should be animated.
     */
    override func viewWillDisappear(_ animated: Bool) {
        if nil != tapkeyKeyObserverRegistration {
            tapkeyKeyObserverRegistration!.close()
            tapkeyKeyObserverRegistration = nil
        }
        
        if nil != tapkeyBluetoothStateObserverRegistration {
            tapkeyBluetoothStateObserverRegistration!.close()
            tapkeyBluetoothStateObserverRegistration = nil
        }
        
        stopScanning()
    }
}
