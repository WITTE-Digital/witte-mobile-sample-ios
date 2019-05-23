//
//  ViewController.swift
//  witte-mobile-sample
//

import UIKit
import TapkeyMobileLib
import witte_mobile_library

class ViewController: UIViewController {

    private var _witteConfiguration: WDConfiguration!
    private var _witteIdentityProvider: WitteIdentityProvider!
    private var _witteUserId: Int = 0;

    private var _tapkeyKeyManager: TkKeyManager?;
    private var _tapkeyUserManager: TkUserManager?
    private var _tapkeyConfigManager: TkConfigManager?;
    private var _tapkeyBleLockManager: TkBleLockManager?;
    private var _tapkeyCommandExecutionFacade: TkCommandExecutionFacade?;
    private var _tapkeyKeys: [NetTpkyMcModelWebviewCachedKeyInformation] = [];

    private var _tapkeyKeyObserver: TkObserver<Void>?;
    private var _tapkeyKeyObserverRegistration: TkObserverRegistration?;
    private var _tapkeyBluetoothObserver: TkObserver<AnyObject>?;
    private var _tapkeyBluetoothObserverRegistration: TkObserverRegistration?;
    private var _tapkeyBluetoothStateObserver: TkObserver<NetTpkyMcModelBluetoothState>?;
    private var _tapkeyBluetoothStateObserverRegistration: TkObserverRegistration?;

    var _scanInProgress: Bool = false;

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
        reloadLocalKeys(forceUpdate: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let app: AppDelegate = UIApplication.shared.delegate as! AppDelegate
        _witteConfiguration = app.witteConfiguration
        _witteIdentityProvider = app.witteIdentityProvider
        _witteUserId = app.witteUserId

        let tapkeyServiceFactory = app.tapkeyServiceFactory
        _tapkeyKeyManager = tapkeyServiceFactory.getKeyManager()
        _tapkeyUserManager = tapkeyServiceFactory.getUserManager()
        _tapkeyConfigManager = tapkeyServiceFactory.getConfigManager()
        _tapkeyBleLockManager = tapkeyServiceFactory.getBleLockManager()
        _tapkeyCommandExecutionFacade = tapkeyServiceFactory.getCommandExecutionFacade()

        // update label content
        _labelCustomerId.text = String(_witteConfiguration.witteCustomerId)
        _labelSubscriptionKey.text = _witteConfiguration.witteSubscriptionKey
        _labelSdkKey.text = _witteConfiguration.witteSdkKey
        _labelUserId.text = String(app.witteUserId)

        //_textFieldBoxId.text = "C1-1F-8E-7C"
        
        // initially disable triggerLock button
        updateButtonStates()

        // hide keyboard on tap
        view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))

        _tapkeyKeyObserver = TkObserver({ (aVoid: Void?) in
            NSLog("Tapkey KeyObserver invocation")
            self.reloadLocalKeys(forceUpdate: false)
        })

        _tapkeyBluetoothObserver = TkObserver({ (any: AnyObject?) in
            NSLog("Tapkey BluetoothObserver invocation")
        });

        _tapkeyBluetoothStateObserver = TkObserver({ (newBluetoothState: NetTpkyMcModelBluetoothState?) in
            NSLog("Tapkey BluetoothStateObserver invocation")
            self.startScanning()
        })
    }

    private func updateButtonStates() {
        if(!_tapkeyUserManager!.hasUsers()){
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
        if (!_tapkeyUserManager!.hasUsers()) {
            
            // retrieve idToken and create identity object
            let emptyUser = NetTpkyMcModelUser()
            _witteIdentityProvider.refreshToken(user: emptyUser, cancellationToken: TkCancellationToken_None)
                .continueOnUi { (identity: NetTpkyMcModelIdentity?) -> Void in
                    
                    // authenticate with identity object
                    self._tapkeyUserManager!.authenticateAsync(identity: identity!, cancellationToken: TkCancellationToken_None)
                        .continueOnUi({ (user: NetTpkyMcModelUser?) -> Void in
                            
                            // update ui
                            self.updateButtonStates()
                            
                            // start scanning for flinkey boxes
                            self.startScanning()
                            
                            // refresh list of local keys
                            self.reloadLocalKeys(forceUpdate: true)
                        })
                        .catchOnUi({ (e: NSException?) -> Void in
                            NSLog("Authentication failed. \(String(describing: e?.reason))");
                        })
                        .conclude();
                }
                .catchOnUi { (e: NSException?) -> Void in
                    NSLog("Identity generation with idToken failed. \(String(describing: e?.reason))");
                }
                .conclude()
        }
    }

    //
    // Logout from the Tapkey SDK
    //
    private func logout() {
        let user = _tapkeyUserManager!.getFirstUser()
        if (nil != user) {
            _tapkeyUserManager!.logOff(user: user!, cancellationToken: TkCancellationToken_None)
                .continueOnUi({(continuation: (Void?)) -> Void in
                    self.updateButtonStates()
                })
                .catchOnUi ({ (e: NSException?) -> Void? in
                    NSLog("Logout failed. \(String(describing: e?.reason))")
                })
                .conclude();
        }
    }

    //
    // Start scanning for flinkey boxes
    //
    private func startScanning() {
        let bluetoothState = _tapkeyConfigManager?.getBluetoothState()
        if (bluetoothState == NetTpkyMcModelBluetoothState.bluetooth_ENABLED()) {
            if (!_scanInProgress) {
                _scanInProgress = true;
                _tapkeyBleLockManager!.startForegroundScan();
            }
        } else {
            // bluetooth is not enabled (anymore),
            // we stop the scanning procedure in case it is already running
            stopScanning()
        }
    }

    //
    // Stop scanning for flinkey boxes
    //
    private func stopScanning() {
        if (_scanInProgress) {
            _tapkeyBleLockManager!.stopForegroundScan();
            _scanInProgress = false;
        }
    }

    //
    // query for this user's keys asynchronously
    //
    private func reloadLocalKeys(forceUpdate: Bool) {
        if (_tapkeyUserManager!.hasUsers()) {
            let user = _tapkeyUserManager!.getFirstUser()
            _tapkeyKeyManager!.queryLocalKeysAsync(user: user!, forceUpdate: forceUpdate, cancellationToken: TkCancellationToken_None)
                    .continueOnUi { (keys: [NetTpkyMcModelWebviewCachedKeyInformation]?) -> Void in
                        self._tapkeyKeys = keys ?? [];
                    }
                    .catchOnUi { (e: NSException?) in
                        NSLog("Query local keys failed. \(String(describing: e?.reason))");
                    }
                    .conclude();
        }
    }

    //
    // Open/close the flinkey box
    //
    private func triggerLock() {
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
        if(!_tapkeyBleLockManager!.isLockNearby(physicalLockId: physicalLockId)) {
            let alert = UIAlertController(title: nil, message: "The box \(boxId!) is not in reach.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            present(alert, animated: true)
            return;
        }

        _ = _tapkeyBleLockManager!.executeCommandAsync(deviceIds: [],physicalLockId: physicalLockId, commandFunc:
            { (tlcConnection: NetTpkyMcTlcpTlcpConnection?) -> TkPromise<NetTpkyMcModelCommandResult> in
                return self._tapkeyCommandExecutionFacade!.triggerLockAsync(tlcConnection, cancellationToken: TkCancellationToken_None)
            }, cancellationToken: TkCancellationToken_None)
            .continueOnUi({ (commandResult: NetTpkyMcModelCommandResult?) -> Bool in
                let code: NetTpkyMcModelCommandResult_CommandResultCode = commandResult?.getCode() ?? NetTpkyMcModelCommandResult_CommandResultCode.technicalError();
                switch(code) {
                case NetTpkyMcModelCommandResult_CommandResultCode.ok():
                    let responseData = commandResult?.getResponseData()
                    if(nil != responseData) {
                        let bytes = responseData! as! IOSByteArray
                        let data = bytes.toNSData()
                        let boxFeedback = WDBoxFeedback(responseData: data!)
                        
                        if(WDBoxState.unlocked == boxFeedback.boxState) {
                            NSLog("Box has been opened")
                        }
                        else if(WDBoxState.locked == boxFeedback.boxState) {
                            NSLog("Box has been closed")
                        }
                        else if(WDBoxState.drawerOpen == boxFeedback.boxState) {
                            NSLog("The drawer of the Box is open")
                        }
                    }
                    
                    return true;
                    
                default:
                    return false;
                }
            })
            .catchOnUi({ (e:NSException?) -> Bool in
                NSLog("Trigger lock failed")
                return false;
            });
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if (nil == _tapkeyKeyObserverRegistration) {
            _tapkeyKeyObserverRegistration = _tapkeyKeyManager!
                    .getKeyUpdateObserveable()
                    .addObserver(_tapkeyKeyObserver!);
        }

        if (nil == _tapkeyBluetoothObserverRegistration) {
            _tapkeyBluetoothObserverRegistration = _tapkeyBleLockManager!
                    .getLocksChangedObservable()
                    .addObserver(_tapkeyBluetoothObserver!);
        }

        if (nil == _tapkeyBluetoothStateObserverRegistration) {
            _tapkeyBluetoothStateObserverRegistration = _tapkeyConfigManager!
                    .observerBluetoothState()
                    .addObserver(_tapkeyBluetoothStateObserver!);
        }

        startScanning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        if (nil != _tapkeyKeyObserverRegistration) {
            _tapkeyKeyObserverRegistration!.close();
            _tapkeyKeyObserverRegistration = nil;
        }

        if (nil != _tapkeyBluetoothObserverRegistration) {
            _tapkeyBluetoothObserverRegistration!.close();
            _tapkeyBluetoothObserverRegistration = nil;
        }

        if (nil != _tapkeyBluetoothStateObserverRegistration) {
            _tapkeyBluetoothStateObserverRegistration!.close();
            _tapkeyBluetoothStateObserverRegistration = nil;
        }

        stopScanning()
    }
}
