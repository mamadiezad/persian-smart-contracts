// SPDX-License-Identifier: MIT
// ═══════════════════════════════════════════════════════════════
// 📜 ReferralToken — توکن با سیستم زیرمجموعه‌گیری
// ═══════════════════════════════════════════════════════════════
// ویژگی‌ها:
// • توکن ERC20 با قابلیت ارتقا (UUPS)
// • سیستم دعوت و پاداش زیرمجموعه
// • قفل سود (Vesting) برای تیم
// • سوزاندن توکن (Burn)
// • ضرب سکه (Mint) توسط مالک
// • کارمزد بر روی انتقالات

pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract ReferralToken is Initializable, ERC20Upgradeable, UUPSUpgradeable, OwnableUpgradeable {

    // ===== Referral System =====
    mapping(address => address) public referrals;     // کاربر → دعوت‌کننده
    mapping(address => uint256) public referralCount;  // تعداد دعوت‌های موفق
    uint256 public referralBonus;                     // پاداش هر دعوت (تعداد توکن)
    uint256 public maxReferralLevels;                 // حداکثر سطوح (مثل ۳ سطح)

    // ===== Fee System =====
    uint256 public transferFeeRate;   // کارمزد انتقال (basis points, 100 = 1%)
    uint256 public burnRate;          // درصد سوزاندن از کارمزد
    address public feeWallet;         // کیف پول دریافت کارمزد

    // ===== Vesting =====
    struct VestingSchedule {
        address beneficiary;
        uint256 totalAmount;
        uint256 startTime;
        uint256 duration;
        uint256 claimed;
        bool active;
    }

    VestingSchedule[] public vestingSchedules;
    uint256 public maxSupply;

    // ===== Events =====
    event ReferralReward(address indexed referrer, address indexed referee, uint256 amount);
    event ReferralBonusChanged(uint256 newBonus);
    event FeeWalletChanged(address newWallet);
    event VestingCreated(address indexed beneficiary, uint256 amount, uint256 duration);
    event VestingClaimed(address indexed beneficiary, uint256 amount);

    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        uint256 _referralBonus,
        uint256 _transferFeeRate,
        address _feeWallet
    ) public initializer {
        __ERC20_init(_name, _symbol);
        __UUPSUpgradeable_init();
        __Ownable_init(msg.sender);

        referralBonus = _referralBonus;
        transferFeeRate = _transferFeeRate;
        feeWallet = _feeWallet;
        maxReferralLevels = 3;
        maxSupply = 1_000_000_000 * 10**18; // 1 میلیارد توکن
        burnRate = 2000; // 20% از کارمزد سوزانده شود

        _mint(msg.sender, _initialSupply);
    }

    // ===== Referral =====

    /// @notice ثبت کد دعوت (موقع خرید توکن)
    function setReferrer(address _referrer) external {
        require(referrals[msg.sender] == address(0), "قبلاً ثبت شده");
        require(_referrer != msg.sender, "نمی‌توانی خودت را دعوت کنی");
        require(_referrer != address(0), "آدرس نامعتبر");

        referrals[msg.sender] = _referrer;
        referralCount[_referrer]++;

        // پاداش سطح اول
        _mint(_referrer, referralBonus);
        emit ReferralReward(_referrer, msg.sender, referralBonus);

        // پاداش سطوح بالاتر (مثلاً ۵۰٪ از پاداش سطح اول)
        address upline = referrals[_referrer];
        for (uint256 i = 1; i < maxReferralLevels; i++) {
            if (upline == address(0)) break;
            uint256 levelBonus = (referralBonus * (100 - (i * 30))) / 100;
            if (levelBonus > 0) {
                _mint(upline, levelBonus);
                emit ReferralReward(upline, msg.sender, levelBonus);
            }
            upline = referrals[upline];
        }
    }

    // ===== Transfer with Fee =====

    function transfer(address to, uint256 amount) public override returns (bool) {
        uint256 fee = (amount * transferFeeRate) / 10000;
        uint256 burnAmount = (fee * burnRate) / 10000;
        uint256 feeToWallet = fee - burnAmount;
        uint256 amountAfterFee = amount - fee;

        if (fee > 0) {
            if (burnAmount > 0) _burn(_msgSender(), burnAmount);
            if (feeToWallet > 0) _transfer(_msgSender(), feeWallet, feeToWallet);
        }

        _transfer(_msgSender(), to, amountAfterFee);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        uint256 fee = (amount * transferFeeRate) / 10000;
        uint256 burnAmount = (fee * burnRate) / 10000;
        uint256 feeToWallet = fee - burnAmount;
        uint256 amountAfterFee = amount - fee;

        if (fee > 0) {
            if (burnAmount > 0) _burn(from, burnAmount);
            if (feeToWallet > 0) _transfer(from, feeWallet, feeToWallet);
        }

        _transfer(from, to, amountAfterFee);
        _approve(from, _msgSender(), allowance(from, _msgSender()) - amount);
        return true;
    }

    // ===== Vesting =====

    /// @notice ایجاد برنامه قفل سود برای تیم
    function createVesting(address _beneficiary, uint256 _amount, uint256 _durationDays) external onlyOwner {
        require(_beneficiary != address(0), "آدرس نامعتبر");
        require(_amount > 0, "مبلغ باید بیشتر از صفر باشد");
        require(balanceOf(msg.sender) >= _amount, "موجودی کافی نیست");

        vestingSchedules.push(VestingSchedule({
            beneficiary: _beneficiary,
            totalAmount: _amount,
            startTime: block.timestamp,
            duration: _durationDays * 1 days,
            claimed: 0,
            active: true
        }));

        _transfer(msg.sender, address(this), _amount);
        emit VestingCreated(_beneficiary, _amount, _durationDays);
    }

    /// @notice برداشت از قفل سود
    function claimVesting(uint256 vestingId) external {
        VestingSchedule storage schedule = vestingSchedules[vestingId];
        require(schedule.beneficiary == msg.sender, "فقط ذی‌نفع");
        require(schedule.active, "غیرفعال");
        require(block.timestamp >= schedule.startTime, "هنوز شروع نشده");

        uint256 elapsed = block.timestamp - schedule.startTime;
        uint256 vestedAmount = (schedule.totalAmount * elapsed) / schedule.duration;
        uint256 claimable = vestedAmount - schedule.claimed;

        if (elapsed >= schedule.duration) {
            claimable = schedule.totalAmount - schedule.claimed;
            schedule.active = false;
        }

        require(claimable > 0, "چیزی برای برداشت نیست");
        schedule.claimed += claimable;
        _transfer(address(this), msg.sender, claimable);

        emit VestingClaimed(msg.sender, claimable);
    }

    // ===== Admin =====

    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= maxSupply, "بیش از حداکثر عرضه");
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function setReferralBonus(uint256 _bonus) external onlyOwner {
        referralBonus = _bonus;
        emit ReferralBonusChanged(_bonus);
    }

    function setFeeWallet(address _wallet) external onlyOwner {
        feeWallet = _wallet;
        emit FeeWalletChanged(_wallet);
    }

    // ===== UUPS =====
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
