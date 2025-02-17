// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @dev Pool IDs:
/// @dev 0 = 0.005 ETH pool
/// @dev 1 = 0.01 ETH pool
/// @dev 2 = 0.1 ETH pool
/// @dev 3 = 1 ETH pool
/// @dev 4 = 0.05 ETH pool

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IVeilETHPool} from "../interfaces/IVeilETHPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVeilVerifiedOnchain} from "../verify/iVerify.sol";
import {IRewardsTracker} from "../Incentives/IRewardsTracker.sol";

/// @custom:oz-upgrades-from VeilValidatorV4
contract VeilValidatorV5 is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    /// @dev Errors
    error DepositsDisabled();
    error NotAllowedToDeposit();
    error InsufficientVeilTokens();
    error IncorrectETHAmount();
    error FeeTransferFailed();
    error TokenAlreadySet();
    error OnlyVeilManager();
    error InvalidPoolSize();
    error DailyDepositLimitReached();

    /// @dev Events
    event Deposited(address indexed depositor, uint8 indexed poolSize, uint256 amount, uint256 fee);
    event DepositorStatusChanged(address indexed depositor, bool indexed isAllowed, string details);
    event ManagerChanged(address indexed oldManager, address indexed newManager);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientChanged(address indexed oldRecipient, address indexed newRecipient);
    event DepositStateChanged(uint8 indexed poolSize, bool enabled);
    event VeilTokenSet(address indexed tokenAddress, uint256 requiredAmount);
    event VeilTokenAmountSet(address indexed tokenAddress, uint256 requiredAmount);
    event DepositLimitUpdated(uint8 indexed poolSize, uint256 newLimit);
    event PoolVeilAmountSet(uint8 indexed poolSize, uint256 newAmount);

    /// @dev Veil Validator variables
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public depositFee;
    address public veilManager;
    address public feeRecipient;

    /// @dev Reference to the Veil pools
    bool public deposit0005Enabled;
    bool public deposit005Enabled;
    bool public deposit001Enabled;
    bool public deposit01Enabled;
    bool public deposit1Enabled;
    IVeilETHPool public veil0005ETH;
    IVeilETHPool public veil005ETH;
    IVeilETHPool public veil001ETH;
    IVeilETHPool public veil01ETH;
    IVeilETHPool public veil1ETH;

    /// @dev Deposit limits for non verified pools
    uint256 public deposit0005Limit;
    uint256 public deposit005Limit;
    /// @dev Verified depositors details
    uint256 public depositorCount;
    mapping(address => bool) public allowedDepositors;
    mapping(address => string) public depositorDetails;

    /// Veil Token
    IERC20 public veilToken;
    uint256 public veilAmount;

    /// @dev Non verified pools deposit limits
    mapping(uint256 => uint256) public dailyDeposits0005;
    mapping(uint256 => uint256) public dailyDeposits005;

    // onchain verification helper contract
    IVeilVerifiedOnchain public veilVerifiedOnchain;

    /// verified pools deposit limits
    uint256 public deposit001Limit;
    uint256 public deposit01Limit;
    uint256 public deposit1Limit;
    /// @dev Maps day => address => number of deposits for each pool
    mapping(uint256 => mapping(address => uint256)) public dailyDeposits001;
    mapping(uint256 => mapping(address => uint256)) public dailyDeposits01;
    mapping(uint256 => mapping(address => uint256)) public dailyDeposits1;

    /// @dev Maps pool size => required veil amount
    mapping(uint8 => uint256) public poolVeilAmount;

    /// @dev Address of the rewards tracker contract
    IRewardsTracker public rewardsTracker;

    /// @dev Storage gap for future upgrades
    uint256[41] private __gap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the contract with the pool address and deployer
    function initialize(
        address _veil0005ETH,
        address _veil005ETH,
        address _veil001ETH,
        address _veil01ETH,
        address _veil1ETH
    ) public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        veil0005ETH = IVeilETHPool(_veil0005ETH);
        veil005ETH = IVeilETHPool(_veil005ETH);
        veil001ETH = IVeilETHPool(_veil001ETH);
        veil01ETH = IVeilETHPool(_veil01ETH);
        veil1ETH = IVeilETHPool(_veil1ETH);
        depositFee = 50;
        feeRecipient = msg.sender;
    }

    /// @dev Deposits ETH into the 0.005 ETH pool with a fee
    function deposit0005ETH(bytes32 commitment) external payable nonReentrant {
        if (!deposit0005Enabled) revert DepositsDisabled();
        if (!_hasVeil(msg.sender, 0)) revert InsufficientVeilTokens();

        uint256 currentDay = getCurrentDay();
        if (dailyDeposits0005[currentDay] >= deposit0005Limit) revert DailyDepositLimitReached();

        uint256 denomination = veil0005ETH.denomination();
        uint256 fee = (denomination * depositFee) / BASIS_POINTS;
        uint256 depositAmount = denomination;
        if (msg.value != depositAmount + fee) revert IncorrectETHAmount();

        (bool success,) = feeRecipient.call{value: fee}("");
        if (!success) revert FeeTransferFailed();

        dailyDeposits0005[currentDay]++;
        veil0005ETH.deposit{value: depositAmount}(commitment);

        emit Deposited(msg.sender, 0, depositAmount, fee);
    }

    /// @dev Deposits ETH into the 0.05 ETH pool with a fee
    function deposit005ETH(bytes32 commitment) external payable nonReentrant {
        if (!deposit005Enabled) revert DepositsDisabled();
        if (!_hasVeil(msg.sender, 4)) revert InsufficientVeilTokens();

        uint256 currentDay = getCurrentDay();
        if (dailyDeposits005[currentDay] >= deposit005Limit) revert DailyDepositLimitReached();

        uint256 denomination = veil005ETH.denomination();
        uint256 fee = (denomination * depositFee) / BASIS_POINTS;
        uint256 depositAmount = denomination;
        if (msg.value != depositAmount + fee) revert IncorrectETHAmount();

        (bool success,) = feeRecipient.call{value: fee}("");
        if (!success) revert FeeTransferFailed();

        dailyDeposits005[currentDay]++;
        veil005ETH.deposit{value: depositAmount}(commitment);

        emit Deposited(msg.sender, 4, depositAmount, fee);
    }

    /// @dev Deposits ETH into the 0.01 ETH pool with a fee
    function deposit001ETH(bytes32 commitment) external payable nonReentrant {
        if (!deposit001Enabled) revert DepositsDisabled();
        if (!isAllowedDepositor(msg.sender)) revert NotAllowedToDeposit();
        if (!_hasVeil(msg.sender, 1)) revert InsufficientVeilTokens();

        uint256 currentDay = getCurrentDay();
        if (dailyDeposits001[currentDay][msg.sender] >= deposit001Limit) revert DailyDepositLimitReached();

        uint256 denomination = veil001ETH.denomination();
        uint256 fee = (denomination * depositFee) / BASIS_POINTS;
        uint256 depositAmount = denomination;
        if (msg.value != depositAmount + fee) revert IncorrectETHAmount();

        (bool success,) = feeRecipient.call{value: fee}("");
        if (!success) revert FeeTransferFailed();

        dailyDeposits001[currentDay][msg.sender]++;
        veil001ETH.deposit{value: depositAmount}(commitment);

        emit Deposited(msg.sender, 1, depositAmount, fee);
    }

    /// @dev Deposits ETH into the 0.1 ETH pool with a fee
    function deposit01ETH(bytes32 commitment) external payable nonReentrant {
        if (!deposit01Enabled) revert DepositsDisabled();
        if (!isAllowedDepositor(msg.sender)) revert NotAllowedToDeposit();
        if (!_hasVeil(msg.sender, 2)) revert InsufficientVeilTokens();

        uint256 currentDay = getCurrentDay();
        if (dailyDeposits01[currentDay][msg.sender] >= deposit01Limit) revert DailyDepositLimitReached();

        uint256 denomination = veil01ETH.denomination();
        uint256 fee = (denomination * depositFee) / BASIS_POINTS;
        uint256 depositAmount = denomination;
        if (msg.value != depositAmount + fee) revert IncorrectETHAmount();

        (bool success,) = feeRecipient.call{value: fee}("");
        if (!success) revert FeeTransferFailed();

        /// rewards tracking
        rewardsTracker.recordDeposit(commitment, 2, msg.sender);

        dailyDeposits01[currentDay][msg.sender]++;
        veil01ETH.deposit{value: depositAmount}(commitment);

        emit Deposited(msg.sender, 2, depositAmount, fee);
    }

    /// @dev Deposits ETH into the 1 ETH pool with a fee
    function deposit1ETH(bytes32 commitment) external payable nonReentrant {
        if (!deposit1Enabled) revert DepositsDisabled();
        if (!isAllowedDepositor(msg.sender)) revert NotAllowedToDeposit();
        if (!_hasVeil(msg.sender, 3)) revert InsufficientVeilTokens();

        uint256 currentDay = getCurrentDay();
        if (dailyDeposits1[currentDay][msg.sender] >= deposit1Limit) revert DailyDepositLimitReached();

        uint256 denomination = veil1ETH.denomination();
        uint256 fee = (denomination * depositFee) / BASIS_POINTS;
        uint256 depositAmount = denomination;
        if (msg.value != depositAmount + fee) revert IncorrectETHAmount();

        (bool success,) = feeRecipient.call{value: fee}("");
        if (!success) revert FeeTransferFailed();

        dailyDeposits1[currentDay][msg.sender]++;
        veil1ETH.deposit{value: depositAmount}(commitment);

        emit Deposited(msg.sender, 3, depositAmount, fee);
    }

    /// @dev Returns true if address is allowed to deposit
    /// @return True if allowed, false otherwise
    function isAllowedDepositor(address _depositor) public view returns (bool) {
        // if onchain verification is enabled, check if the address is verified
        if (address(veilVerifiedOnchain) != address(0)) {
            // If verified onchain, return true
            if (veilVerifiedOnchain.isVerified(_depositor)) {
                return true;
            }
        }

        // If not verified onchain or verification failed, check allowedDepositors
        return allowedDepositors[_depositor];
    }

    /// @dev Helper function to get the current day
    function getCurrentDay() public view returns (uint256) {
        return block.timestamp / 1 days;
    }

    /// @dev Checks if an address holds more than the required amount of VEIL tokens
    /// @dev Returns true if veil token is not set up yet (address(0))
    function _hasVeil(address _depositor, uint8 _poolSize) internal view returns (bool) {
        return veilToken.balanceOf(_depositor) >= poolVeilAmount[_poolSize];
    }

    /// @dev Returns the number of deposits made by an address for a specific pool on a given day
    /// @param _depositor Address to check deposits for
    /// @param _poolSize Pool ID (1 = 0.01 ETH, 2 = 0.1 ETH, 3 = 1 ETH)
    /// @param _day Day to check (0 for current day, or specific day timestamp / 1 days)
    /// @return count Number of deposits made on the specified day
    function getDailyDeposits(address _depositor, uint8 _poolSize, uint256 _day) external view returns (uint256) {
        uint256 day;
        if (_day == 0) {
            day = getCurrentDay();
        } else {
            day = _day;
        }

        if (_poolSize == 1) {
            return dailyDeposits001[day][_depositor];
        } else if (_poolSize == 2) {
            return dailyDeposits01[day][_depositor];
        } else if (_poolSize == 3) {
            return dailyDeposits1[day][_depositor];
        }

        revert InvalidPoolSize();
    }

    /// @dev Sets the address of the VEIL token. Can only be set once.
    function setVeilToken(address _veilToken) external onlyOwner {
        if (address(veilToken) != address(0)) revert TokenAlreadySet();
        veilToken = IERC20(_veilToken);
        emit VeilTokenSet(_veilToken, veilAmount);
    }

    /// @dev Sets whether an address is allowed to make deposits
    function setAllowedDepositor(address _depositor, bool _isAllowed, string memory _details) public {
        if (msg.sender != veilManager) revert OnlyVeilManager();

        /// track the number of depositors
        if (_isAllowed) {
            if (allowedDepositors[_depositor] != _isAllowed) {
                depositorCount++;
            }
        } else {
            if (allowedDepositors[_depositor] != _isAllowed) {
                depositorCount--;
            }
        }

        /// update the allowed depositors and details
        allowedDepositors[_depositor] = _isAllowed;
        depositorDetails[_depositor] = _details;
        emit DepositorStatusChanged(_depositor, _isAllowed, _details);
    }

    /// @dev Batch sets multiple addresses as allowed depositors
    /// @param _depositors Array of addresses to set as allowed
    /// @param _details Array of details strings corresponding to each depositor
    function batchSetAllowedDepositors(address[] calldata _depositors, string[] calldata _details) external {
        if (msg.sender != veilManager) revert OnlyVeilManager();
        if (_depositors.length != _details.length) revert("Array lengths must match");

        for (uint256 i = 0; i < _depositors.length; i++) {
            setAllowedDepositor(_depositors[i], true, _details[i]);
        }
    }

    /// @dev Sets the address of the manager that can manage depositors
    function setManager(address _manager) external onlyOwner {
        address oldManager = veilManager;
        veilManager = _manager;
        emit ManagerChanged(oldManager, _manager);
    }

    /// @dev Sets the fee charged on deposits in basis points
    function setDepositFee(uint256 _depositFee) external onlyOwner {
        uint256 oldFee = depositFee;
        depositFee = _depositFee;
        emit FeeUpdated(oldFee, _depositFee);
    }

    /// @dev Sets the address that receives deposit fees
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        address oldRecipient = feeRecipient;
        feeRecipient = _feeRecipient;
        emit FeeRecipientChanged(oldRecipient, _feeRecipient);
    }

    /// @dev Enables or disables deposits for a specific pool
    function setDepositEnabled(uint8 _poolSize, bool _depositEnabled) external onlyOwner {
        if (_poolSize > 4) revert InvalidPoolSize();

        if (_poolSize == 0) {
            deposit0005Enabled = _depositEnabled;
        }
        if (_poolSize == 1) {
            deposit001Enabled = _depositEnabled;
        }
        if (_poolSize == 2) {
            deposit01Enabled = _depositEnabled;
        }
        if (_poolSize == 3) {
            deposit1Enabled = _depositEnabled;
        }
        if (_poolSize == 4) {
            deposit005Enabled = _depositEnabled;
        }
        emit DepositStateChanged(_poolSize, _depositEnabled);
    }

    /// @dev Sets the daily deposit limit for a specific pool
    function setDepositLimit(uint8 _poolSize, uint256 _limit) external onlyOwner {
        if (_poolSize > 4) revert InvalidPoolSize();

        if (_poolSize == 0) {
            deposit0005Limit = _limit;
        }
        if (_poolSize == 1) {
            deposit001Limit = _limit;
        }
        if (_poolSize == 2) {
            deposit01Limit = _limit;
        }
        if (_poolSize == 3) {
            deposit1Limit = _limit;
        }
        if (_poolSize == 4) {
            deposit005Limit = _limit;
        }
        emit DepositLimitUpdated(_poolSize, _limit);
    }

    /// @notice Sets the address of the onchain verification contract
    /// @dev Can only be called by owner
    function setVeilVerifiedOnchain(address _veilVerifiedOnchain) external onlyOwner {
        veilVerifiedOnchain = IVeilVerifiedOnchain(_veilVerifiedOnchain);
    }

    /// @dev Sets the required amount of VEIL tokens for a specific pool
    function setPoolVeilAmount(uint8 _poolSize, uint256 _veilAmount) external onlyOwner {
        poolVeilAmount[_poolSize] = _veilAmount;
        emit PoolVeilAmountSet(_poolSize, _veilAmount);
    }

    /// @dev Sets the address of the rewards tracker contract
    function setRewardsTracker(address _rewardsTracker) external onlyOwner {
        rewardsTracker = IRewardsTracker(_rewardsTracker);
    }
}
