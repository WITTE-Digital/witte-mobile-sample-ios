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
    private var _witteUserId: Int = 0;

    private var _tapkeyKeyManager: TKMKeyManager?;
    private var _tapkeyUserManager: TKMUserManager?
    private var _tapkeyBleLockScanner: TKMBleLockScanner?;
    private var _tapkeyBleLockCommunicator: TKMBleLockCommunicator?;
    private var _tapkeyCommandExecutionFacade: TKMCommandExecutionFacade?;
    private var _tapkeyKeys: [TKMKeyDetails] = [];

    private var _tapkeyStartForegroundScanRegistration: TKMObserverRegistration?;
    private var _tapkeyKeyObserverRegistration: TKMObserverRegistration?;
    private var _tapkeyBluetoothStateObserverRegistration: TKMObserverRegistration?;

    @IBOutlet weak var _labelCustomerId: UILabel!
    @IBOutlet weak var _labelSubscriptionKey: UILabel!
    @IBOutlet weak var _labelSdkKey: UILabel!
    @IBOutlet weak var _labelUserId: UILabel!
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
        reloadLocalKeys()
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
                            
                            // refresh list of local keys
                            self.reloadLocalKeys()
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
    private func reloadLocalKeys() {
        if isUserLoggedIn() {
            let userId = _tapkeyUserManager!.users[0]
            _tapkeyKeyManager!.queryLocalKeysAsync(userId: userId, cancellationToken: TKMCancellationTokens.None)
                    .continueOnUi { (keys: [TKMKeyDetails]?) -> Void in
                        self._tapkeyKeys = keys ?? [];
                    }
                    .catchOnUi({ (error: TKMAsyncError) -> Void? in
                        print("Query local keys failed.")
                        return nil
                    })
                    .conclude()
        }
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
        
        let bluetoothAddress = _tapkeyBleLockScanner!.getLock(physicalLockId: physicalLockId)?.bluetoothAddress
        if(nil != bluetoothAddress) {
            _tapkeyBleLockCommunicator!
                .executeCommandAsync(
                    bluetoothAddress: bluetoothAddress!,
                    physicalLockId: physicalLockId,
                    commandFunc: { tlcpConnection in self._tapkeyCommandExecutionFacade!.triggerLockAsync(tlcpConnection, cancellationToken: TKMCancellationTokens.None)},
                    cancellationToken: TKMCancellationTokens.None)
                .continueOnUi{ (commandResult: TKMCommandResult?) -> Bool? in
                    if commandResult?.code == TKMCommandResult.TKMCommandResultCode.ok {
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
                            
                            return true
                        }
                        else {
                            return false
                        }
                    }
                    
                    return false
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
                print("local keys changed")
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
