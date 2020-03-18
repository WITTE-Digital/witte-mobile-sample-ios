//
//  ViewController.swift
//  witte-mobile-sample
//

import UIKit
import TapkeyMobileLib
import witte_mobile_library

class ViewController: UIViewController {

    private var _witteConfiguration: WDConfiguration!
    private var _witteTokenProvider: WitteTokenProvider!
    private var _witteUserId: Int = 0

    private var _tapkeyKeyManager: TKMKeyManager?
    private var _tapkeyUserManager: TKMUserManager?
    private var _tapkeyBleLockScanner: TKMBleLockScanner?
    private var _tapkeyBleLockCommunicator: TKMBleLockCommunicator?
    private var _tapkeyCommandExecutionFacade: TKMCommandExecutionFacade?
    private var _tapkeyNotificationManager: TKMNotificationManager?
    private var _tapkeyKeys: [TKMKeyDetails] = []

    private var _tapkeyStartForegroundScanRegistration: TKMObserverRegistration?
    private var _tapkeyKeyObserverRegistration: TKMObserverRegistration?
    private var _tapkeyBluetoothStateObserverRegistration: TKMObserverRegistration?

    @IBOutlet weak var _labelCustomerId: UILabel!
    @IBOutlet weak var _labelSubscriptionKey: UILabel!
    @IBOutlet weak var _labelSdkKey: UILabel!
    @IBOutlet weak var _labelUserId: UILabel!
    @IBOutlet weak var _labelKeys: UILabel!
    @IBOutlet weak var _buttonLogin: UIButton!
    @IBOutlet weak var _buttonLogout: UIButton!
    @IBOutlet weak var _buttonTriggerLock: UIButton!
    @IBOutlet weak var _buttonReloadLocalKeys: UIButton!
    @IBOutlet weak var _textFieldBoxId: UITextField!

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
        _witteConfiguration = app.witteConfiguration
        _witteTokenProvider = app.witteTokenProvider
        _witteUserId = app.witteUserId

        let tapkeyServiceFactory = app.tapkeyServiceFactory
        _tapkeyKeyManager = tapkeyServiceFactory.keyManager
        _tapkeyUserManager = tapkeyServiceFactory.userManager
        _tapkeyBleLockScanner = tapkeyServiceFactory.bleLockScanner
        _tapkeyBleLockCommunicator = tapkeyServiceFactory.bleLockCommunicator
        _tapkeyCommandExecutionFacade = tapkeyServiceFactory.commandExecutionFacade
        _tapkeyNotificationManager = tapkeyServiceFactory.notificationManager

        // update label content
        _labelCustomerId.text = String(_witteConfiguration.witteCustomerId)
        _labelSubscriptionKey.text = _witteConfiguration.witteSubscriptionKey
        _labelSdkKey.text = _witteConfiguration.witteSdkKey
        _labelUserId.text = String(app.witteUserId)
        
        // initially disable triggerLock button
        updateButtonStates()

        // hide keyboard on tap
        view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
    }

    private func isUserLoggedIn() -> Bool {
        var isLoggedIn = false
        
        if(nil != _tapkeyUserManager) {
            let userIds = _tapkeyUserManager?.users
            if(nil != userIds && 1 == userIds?.count) {
                isLoggedIn = true
            }
        }
        
        return isLoggedIn
    }
    
    private func updateButtonStates() {
        if !isUserLoggedIn() {
            // user not authenticated
            _buttonLogin.isEnabled = true
            _buttonLogout.isEnabled = false
            _buttonTriggerLock.isEnabled = false
            _buttonReloadLocalKeys.isEnabled = false
            _labelKeys.text = ""
        }
        else {
            // user is authenticated
            _buttonLogin.isEnabled = false
            _buttonLogout.isEnabled = true;
            _buttonTriggerLock.isEnabled = true
            _buttonReloadLocalKeys.isEnabled = true
        }
    }
    
    //
    // Login to the Tapkey SDK
    //
    private func login() {
        if !isUserLoggedIn() {
            // query access token
            _witteTokenProvider.accessToken()
                .continueOnUi { (accesToken: String?) -> Void in
                    
                    // login to Tapkey backend
                    self._tapkeyUserManager!.logInAsync(accessToken: accesToken!, cancellationToken: TKMCancellationTokens.None)
                        .continueOnUi{ (userId: String?) -> Void in
                            // update ui
                            self.updateButtonStates()
                            
                            // start scanning for flinkey boxes
                            self.startScanning()
                            
                            // retrieve keys for the current user
                            self._tapkeyNotificationManager!.pollForNotificationsAsync(cancellationToken: TKMCancellationTokens.None)
                            .continueOnUi({ Void in
                                self.queryLocalKeys()
                                return nil
                            })
                            .catchOnUi({ (error: TKMAsyncError) -> Void in
                            })
                            .conclude();
                        }
                        .catchOnUi{(error) -> Void in
                            print("Authentication failed.")
                        }
                        .conclude();
                }
                .catchOnUi { (error: TKMAsyncError?) -> Void in
                    print("Access token query failed. \(String(describing: error?.localizedDescription))")
                }
                .conclude()
        }
    }

    //
    // Logout from the Tapkey SDK
    //
    private func logout() {
        if isUserLoggedIn() {
            let userId = _tapkeyUserManager!.users[0]
            _tapkeyUserManager!
                .logOutAsync(userId: userId, cancellationToken: TKMCancellationTokens.None)
                .continueOnUi{_ in
                }
                .catchOnUi({ (error: TKMAsyncError) -> Void in
                    print(error.localizedDescription)
                })
                .finallyOnUi {
                    self.updateButtonStates()
                }
                .conclude()
        }
        else {
            self.updateButtonStates()
        }
    }

    //
    // Start scanning for flinkey boxes
    //
    private func startScanning() {
        if(nil == _tapkeyStartForegroundScanRegistration) {
            _tapkeyStartForegroundScanRegistration = _tapkeyBleLockScanner?.startForegroundScan()
        }
    }

    //
    // Stop scanning for flinkey boxes
    //
    private func stopScanning() {
        if (nil != _tapkeyStartForegroundScanRegistration) {
            _tapkeyStartForegroundScanRegistration?.close()
            _tapkeyStartForegroundScanRegistration = nil
        }
    }

    //
    // query for this user's keys asynchronously
    //
    private func queryLocalKeys() {
        if isUserLoggedIn() {
            let userId = _tapkeyUserManager!.users[0]
            _tapkeyKeyManager!.queryLocalKeysAsync(userId: userId, cancellationToken: TKMCancellationTokens.None)
                    .continueOnUi { (keys: [TKMKeyDetails]?) -> Void in
                        self._tapkeyKeys = keys ?? [];
                        
                        var sb = ""
                        for key in self._tapkeyKeys {
                            let grant = key.grant
                            if(nil != grant) {
                                let physicalLockId = grant?.getBoundLock()?.getPhysicalLockId();
                                let boxId = WDBoxIdConverter().toBoxId(withPhysicalLockId: physicalLockId!)
                                let grantValidFrom = grant?.getValidFrom()?.toDate() ?? nil
                                let grantValidBefore = grant?.getValidBefore()?.toDate() ?? nil
                                let keyValidBefore = key.validBefore
                                
                                sb.append("• \(boxId)\n")
                                sb.append(" grant starts: \(self.toIsoString(date: grantValidFrom))\n")
                                if(nil != grantValidBefore) {
                                    sb.append(" grant ends: \(self.toIsoString(date: grantValidBefore))\n")
                                }
                                else {
                                    sb.append(" grant ends: unlimited\n")
                                }
                                
                                sb.append(" valid before: \(self.toIsoString(date: keyValidBefore))\n")
                            }
                        }
                        
                        self._labelKeys.text = sb
                    }
                    .catchOnUi({ (error: TKMAsyncError) -> Void? in
                        print("Query local keys failed.")
                        return nil
                    })
                    .conclude()
        }
    }

    open func toIsoString(date: Date?) -> String {
        var str = ""
        
        if (date != nil) {
            let formatter = ISO8601DateFormatter()
            str = formatter.string(from: date!)
        }
        
        return str;
    }
    
    //
    // Open/close the flinkey box
    //
    private func triggerLock() {
        
        // user needs to be logged in
        if(!isUserLoggedIn()) {
            let alert = UIAlertController(title: nil, message: "Please login first", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            present(alert, animated: true)
            return
        }
        
        // get box id from textfield
        let boxId = _textFieldBoxId.text
        if(nil == boxId || boxId!.isEmpty) {
            let alert = UIAlertController(title: nil, message: "Please enter your box ID", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            present(alert, animated: true)
            return;
        }

        // convert box id to physical lock id
        let converter = WDBoxIdConverter()
        let physicalLockId = converter.toPhysicalLockId(withBoxId: boxId!);
        if(physicalLockId.isEmpty) {
            let alert = UIAlertController(title: nil, message: "\(boxId!) is not a valid box Id.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            present(alert, animated: true)
            return;
        }
        
        // check if box is in reach
        if(!_tapkeyBleLockScanner!.isLockNearby(physicalLockId: physicalLockId)) {
            let alert = UIAlertController(title: nil, message: "The box \(boxId!) is not in reach.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            present(alert, animated: true)
            return;
        }
        
        // 60s timeout
        let timeoutMs: Int32 = 60 * 1000
        let timeout = TKMCancellationTokens.fromTimeout(timeoutMs: timeoutMs)
        
        let bluetoothAddress = _tapkeyBleLockScanner!.getLock(physicalLockId: physicalLockId)?.bluetoothAddress
        if(nil != bluetoothAddress) {
            _tapkeyBleLockCommunicator!
                .executeCommandAsync(
                    bluetoothAddress: bluetoothAddress!,
                    physicalLockId: physicalLockId,
                    commandFunc: { tlcpConnection in self._tapkeyCommandExecutionFacade!.triggerLockAsync(tlcpConnection, cancellationToken: timeout)},
                    cancellationToken: timeout)
                .continueOnUi{ (commandResult: TKMCommandResult?) -> Bool? in
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
                        if(nil != responseData) {
                            let bytes = responseData! as! IOSByteArray
                            let data = bytes.toNSData()
                            let boxFeedback = WDBoxFeedback(responseData: data!)
                            
                            if(WDBoxState.unlocked == boxFeedback.boxState) {
                                print("Box has been opened")
                            }
                            else if(WDBoxState.locked == boxFeedback.boxState) {
                                print("Box has been closed")
                            }
                            else if(WDBoxState.drawerOpen == boxFeedback.boxState) {
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
                .catchOnUi{ (error: TKMAsyncError) -> Bool? in
                    print("triggerLock failed")
                    return false
                }
                .conclude()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if (nil == _tapkeyKeyObserverRegistration) {
            _tapkeyKeyObserverRegistration = _tapkeyKeyManager?.keyUpdateObservable.addObserver({ _ in
                self.queryLocalKeys()
            })
        }

        if (nil == _tapkeyBluetoothStateObserverRegistration) {
            _tapkeyBluetoothStateObserverRegistration = _tapkeyBleLockScanner?.observable.addObserver({ _ in
                print("flinkey box availablilty changed")
            })
        }
        
        startScanning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        if (nil != _tapkeyKeyObserverRegistration) {
            _tapkeyKeyObserverRegistration!.close();
            _tapkeyKeyObserverRegistration = nil;
        }

        if (nil != _tapkeyBluetoothStateObserverRegistration) {
            _tapkeyBluetoothStateObserverRegistration!.close();
            _tapkeyBluetoothStateObserverRegistration = nil;
        }

        stopScanning()
    }
}
