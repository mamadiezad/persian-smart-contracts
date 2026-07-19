// SPDX-License-Identifier: MIT
// ═══════════════════════════════════════════════════════════════
// 📜 MultiSigWallet — کیف پول چند امضایی با قفل زمانی
// ═══════════════════════════════════════════════════════════════
// ویژگی‌ها:
// • نیاز به چند امضا برای تایید تراکنش
// • قفل زمانی برای برداشت‌های بزرگ
// • قابلیت آپگرید (UUPS Upgradeable)
// • پشتیبانی از توکن‌های ERC20 و اتر
// • حالت اضطراری (Emergency Pause)

pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MultiSigWallet is Initializable, UUPSUpgradeable, OwnableUpgradeable, PausableUpgradeable {

    // ===== State Variables =====
    address[] public owners;                    // لیست امضاکنندگان
    mapping(address => bool) public isOwner;    // وضعیت امضاکننده
    uint256 public requiredConfirmations;       // تعداد امضای لازم
    uint256 public timelockDuration;            // مدت قفل زمانی (ثانیه)
    uint256 public emergencyDelay;              // تاخیر اضطراری

    struct Transaction {
        address to;                        // مقصد
        uint256 value;                     // مقدار (اتر)
        bytes data;                        // داده (برای توکن‌ها)
        bool executed;                     // اجرا شده؟
        uint256 confirmations;             // تعداد تاییدها
        uint256 proposedAt;                // زمان پیشنهاد
        bool isTokenTransfer;              // انتقال توکن؟
        address tokenAddress;              // آدرس توکن
    }

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmations;
    uint256 public nonce;

    // ===== Events =====
    event TransactionProposed(uint256 indexed txId, address indexed proposer, address to, uint256 value);
    event TransactionConfirmed(uint256 indexed txId, address indexed confirmer);
    event TransactionExecuted(uint256 indexed txId, address indexed executor);
    event OwnerAdded(address indexed newOwner);
    event OwnerRemoved(address indexed removedOwner);
    event TimelockChanged(uint256 newDuration);

    // ===== Modifiers =====
    modifier onlyOwner() {
        require(isOwner[msg.sender], "فقط امضاکنندگان");
        _;
    }

    modifier txExists(uint256 txId) {
        require(txId < transactions.length, "تراکنش وجود ندارد");
        _;
    }

    modifier notExecuted(uint256 txId) {
        require(!transactions[txId].executed, "قبلاً اجرا شده");
        _;
    }

    modifier notConfirmed(uint256 txId) {
        require(!confirmations[txId][msg.sender], "قبلاً تایید کردی");
        _;
    }

    // ===== Initialize (جای constructor) =====
    /// @param _owners لیست امضاکنندگان
    /// @param _requiredConfirmations تعداد امضای مورد نیاز
    function initialize(address[] memory _owners, uint256 _requiredConfirmations, uint256 _timelockDuration) public initializer {
        require(_owners.length > 0, "حداقل یک امضاکننده نیاز است");
        require(_requiredConfirmations > 0 && _requiredConfirmations <= _owners.length, "تعداد امضا نامعتبر");

        __UUPSUpgradeable_init();
        __Ownable_init(msg.sender);
        __Pausable_init();

        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "آدرس نامعتبر");
            require(!isOwner[_owners[i]], "تکراری");
            isOwner[_owners[i]] = true;
            owners.push(_owners[i]);
        }

        requiredConfirmations = _requiredConfirmations;
        timelockDuration = _timelockDuration;
    }

    // ===== Core Functions =====

    /// @notice پیشنهاد تراکنش جدید
    function proposeTransaction(address _to, uint256 _value, bytes memory _data) external onlyOwner whenNotPaused returns (uint256) {
        uint256 txId = transactions.length;
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmations: 0,
            proposedAt: block.timestamp,
            isTokenTransfer: false,
            tokenAddress: address(0)
        }));

        emit TransactionProposed(txId, msg.sender, _to, _value);
        return txId;
    }

    /// @notice پیشنهاد انتقال توکن ERC20
    function proposeTokenTransfer(address _token, address _to, uint256 _amount) external onlyOwner whenNotPaused returns (uint256) {
        uint256 txId = transactions.length;
        transactions.push(Transaction({
            to: _token,
            value: 0,
            data: abi.encodeWithSignature("transfer(address,uint256)", _to, _amount),
            executed: false,
            confirmations: 0,
            proposedAt: block.timestamp,
            isTokenTransfer: true,
            tokenAddress: _token
        }));

        emit TransactionProposed(txId, msg.sender, _token, _amount);
        return txId;
    }

    /// @notice تایید یک تراکنش
    function confirmTransaction(uint256 txId) external onlyOwner txExists(txId) notExecuted(txId) notConfirmed(txId) whenNotPaused {
        confirmations[txId][msg.sender] = true;
        transactions[txId].confirmations++;
        emit TransactionConfirmed(txId, msg.sender);

        if (transactions[txId].confirmations >= requiredConfirmations) {
            executeTransaction(txId);
        }
    }

    /// @notice اجرای تراکنش
    function executeTransaction(uint256 txId) internal txExists(txId) notExecuted(txId) {
        require(transactions[txId].confirmations >= requiredConfirmations, "امضای کافی نیست");
        require(block.timestamp >= transactions[txId].proposedAt + timelockDuration, "در قفل زمانی");

        Transaction storage txn = transactions[txId];
        txn.executed = true;

        if (txn.isTokenTransfer) {
            (bool success, ) = txn.to.call(txn.data);
            require(success, "انتقال توکن ناموفق");
        } else if (txn.value > 0) {
            (bool success, ) = payable(txn.to).call{value: txn.value}("");
            require(success, "انتقال اتر ناموفق");
        } else {
            (bool success, ) = txn.to.call(txn.data);
            require(success, "اجرا ناموفق");
        }

        emit TransactionExecuted(txId, msg.sender);
    }

    /// @notice دریافت تعداد تاییدهای یک تراکنش
    function getConfirmations(uint256 txId) external view returns (address[] memory) {
        address[] memory _confirmations = new address[](owners.length);
        uint256 count = 0;
        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[txId][owners[i]]) {
                _confirmations[count] = owners[i];
                count++;
            }
        }
        return _confirmations;
    }

    /// @notice دریافت تعداد تراکنش‌ها
    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    // ===== Owner Management =====

    /// @notice افزودن امضاکننده جدید
    function addOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "آدرس نامعتبر");
        require(!isOwner[_newOwner], "قبلاً امضاکننده است");
        isOwner[_newOwner] = true;
        owners.push(_newOwner);
        emit OwnerAdded(_newOwner);
    }

    /// @notice حذف امضاکننده
    function removeOwner(address _owner) external onlyOwner {
        require(isOwner[_owner], "امضاکننده نیست");
        isOwner[_owner] = false;
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == _owner) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }
        }
        require(requiredConfirmations <= owners.length, "تعداد امضا بیش از حد");
        emit OwnerRemoved(_owner);
    }

    /// @notice تغییر تعداد امضای مورد نیاز
    function changeRequiredConfirmations(uint256 _required) external onlyOwner {
        require(_required > 0 && _required <= owners.length, "نامعتبر");
        requiredConfirmations = _required;
    }

    /// @notice تغییر مدت قفل زمانی
    function changeTimelock(uint256 _duration) external onlyOwner {
        timelockDuration = _duration;
        emit TimelockChanged(_duration);
    }

    // ===== Emergency =====
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // ===== UUPS =====
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ===== Receive =====
    receive() external payable {}
}
