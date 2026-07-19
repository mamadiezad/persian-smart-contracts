// SPDX-License-Identifier: MIT
// ═══════════════════════════════════════════════════════════════
// 📜 Escrow — قرارداد امان فریلنسری
// ═══════════════════════════════════════════════════════════════
// ویژگی‌ها:
// • کارفرما پول را در قرارداد قفل می‌کند
// • فریلنسر پس از تایید کارفرما، پول را دریافت می‌کند
// • داوری (Arbitration) برای حل اختلاف
// • آپگریدبل (UUPS)
// • پشتیبانی از توکن ERC20

pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Escrow is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    enum EscrowState { Pending, InProgress, Completed, Disputed, Refunded }
    enum PaymentType { Native, ERC20 }

    struct EscrowDeal {
        address client;           // کارفرما
        address freelancer;       // فریلنسر
        address arbitrator;       // داور
        PaymentType paymentType;  // نوع پرداخت
        address tokenAddress;     // آدرس توکن (اگر ERC20)
        uint256 amount;           // مبلغ
        string description;       // توضیحات پروژه
        EscrowState state;        // وضعیت
        uint256 createdAt;        // زمان ایجاد
        uint256 deadline;         // مهلت تحویل
        string deliverables;      // لینک تحویل
    }

    EscrowDeal[] public deals;
    uint256 public arbitratorFee;  // کارمزد داوری (basis points, 100 = 1%)
    address public platformWallet; // کیف پول پلتفرم

    event DealCreated(uint256 indexed dealId, address indexed client, address indexed freelancer, uint256 amount);
    event DealStarted(uint256 indexed dealId);
    event DeliverableSubmitted(uint256 indexed dealId, string link);
    event DealCompleted(uint256 indexed dealId);
    event DealDisputed(uint256 indexed dealId);
    event DealRefunded(uint256 indexed dealId);
    event ArbitrationResolved(uint256 indexed dealId, address winner, uint256 amount);

    function initialize(address _platformWallet, uint256 _arbitratorFee) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(msg.sender);
        platformWallet = _platformWallet;
        arbitratorFee = _arbitratorFee;
    }

    /// @notice کارفرما یک معامله جدید ایجاد می‌کند
    function createDeal(
        address _freelancer,
        address _arbitrator,
        uint256 _amount,
        string memory _description,
        uint256 _deadline,
        PaymentType _paymentType,
        address _tokenAddress
    ) external payable returns (uint256) {
        require(_freelancer != address(0), "آدرس فریلنسر نامعتبر");
        require(_arbitrator != address(0), "آدرس داور نامعتبر");
        require(_amount > 0, "مبلغ باید بیشتر از صفر باشد");
        require(msg.sender != _freelancer, "کارفرما و فریلنسر نمی‌توانند یکی باشند");

        uint256 dealId = deals.length;

        if (_paymentType == PaymentType.Native) {
            require(msg.value == _amount, "مبلغ ارسال شده با مبلغ قرارداد مطابقت ندارد");
        } else {
            IERC20(_tokenAddress).safeTransferFrom(msg.sender, address(this), _amount);
        }

        deals.push(EscrowDeal({
            client: msg.sender,
            freelancer: _freelancer,
            arbitrator: _arbitrator,
            paymentType: _paymentType,
            tokenAddress: _tokenAddress,
            amount: _amount,
            description: _description,
            state: EscrowState.Pending,
            createdAt: block.timestamp,
            deadline: block.timestamp + _deadline,
            deliverables: ""
        }));

        emit DealCreated(dealId, msg.sender, _freelancer, _amount);
        return dealId;
    }

    /// @notice فریلنسر شروع پروژه را تایید می‌کند
    function startDeal(uint256 dealId) external {
        EscrowDeal storage deal = deals[dealId];
        require(msg.sender == deal.freelancer, "فقط فریلنسر");
        require(deal.state == EscrowState.Pending, "وضعیت نامعتبر");
        deal.state = EscrowState.InProgress;
        emit DealStarted(dealId);
    }

    /// @notice فریلنسر تحویل پروژه را ثبت می‌کند
    function submitDeliverable(uint256 dealId, string memory _link) external {
        EscrowDeal storage deal = deals[dealId];
        require(msg.sender == deal.freelancer, "فقط فریلنسر");
        require(deal.state == EscrowState.InProgress, "پروژه در حال انجام نیست");
        deal.deliverables = _link;
        emit DeliverableSubmitted(dealId, _link);
    }

    /// @notice کارفرما پروژه را تایید و پول را آزاد می‌کند
    function completeDeal(uint256 dealId) external {
        EscrowDeal storage deal = deals[dealId];
        require(msg.sender == deal.client, "فقط کارفرما");
        require(deal.state == EscrowState.InProgress, "پروژه در حال انجام نیست");

        deal.state = EscrowState.Completed;
        _releasePayment(dealId, deal.freelancer, deal.amount);

        emit DealCompleted(dealId);
    }

    /// @notice کارفرما یا فریلنسر می‌تواند اعتراض کند
    function disputeDeal(uint256 dealId) external {
        EscrowDeal storage deal = deals[dealId];
        require(msg.sender == deal.client || msg.sender == deal.freelancer, "فقط طرفین معامله");
        require(deal.state == EscrowState.InProgress, "قابل اعتراض نیست");
        deal.state = EscrowState.Disputed;
        emit DealDisputed(dealId);
    }

    /// @notice داور اختلاف را حل می‌کند
    function resolveDispute(uint256 dealId, address winner, uint256 arbitratorShare) external {
        EscrowDeal storage deal = deals[dealId];
        require(msg.sender == deal.arbitrator, "فقط داور");
        require(deal.state == EscrowState.Disputed, "در حال اختلاف نیست");

        uint256 fee = (deal.amount * arbitratorShare) / 10000;
        uint256 winnerAmount = deal.amount - fee;

        deal.state = winner == deal.freelancer ? EscrowState.Completed : EscrowState.Refunded;

        _releasePayment(dealId, platformWallet, fee);
        _releasePayment(dealId, winner, winnerAmount);

        emit ArbitrationResolved(dealId, winner, winnerAmount);
    }

    /// @notice انصراف و بازگشت پول (قبل از شروع پروژه)
    function cancelDeal(uint256 dealId) external {
        EscrowDeal storage deal = deals[dealId];
        require(msg.sender == deal.client, "فقط کارفرما");
        require(deal.state == EscrowState.Pending, "فقط قبل از شروع");

        deal.state = EscrowState.Refunded;
        _releasePayment(dealId, deal.client, deal.amount);
        emit DealRefunded(dealId);
    }

    function _releasePayment(uint256 dealId, address to, uint256 amount) internal {
        EscrowDeal storage deal = deals[dealId];
        if (deal.paymentType == PaymentType.Native) {
            (bool success, ) = payable(to).call{value: amount}("");
            require(success, "انتقال ناموفق");
        } else {
            IERC20(deal.tokenAddress).safeTransfer(to, amount);
        }
    }

    function getDealCount() external view returns (uint256) {
        return deals.length;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
