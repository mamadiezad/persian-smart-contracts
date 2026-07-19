# 📜 Persian Smart Contracts — قراردادهای هوشمند فارسی

> **مجموعه‌ای از قراردادهای هوشمند حرفه‌ای** با قابلیت آپگرید (UUPS Upgradeable Proxy) — قابل اجرا روی Polygon, BSC, Ethereum و سایر شبکه‌های EVM.

[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-363636?logo=solidity)](https://soliditylang.org)
[![Hardhat](https://img.shields.io/badge/Hardhat-2.22-FFF100?logo=hardhat)](https://hardhat.org)
[![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-Upgradeable-4E5EE4?logo=openzeppelin)](https://openzeppelin.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue)](LICENSE)

---

## 📦 قراردادها

| قرارداد | شبکه | توضیح | وضعیت |
|:-------:|:----:|:------|:-----:|
| 🏛️ **MultiSigWallet** | Polygon ✓ BSC ✓ ETH ✓ | کیف پول چند امضایی با قفل زمانی | ✅ کامل |
| 🤝 **Escrow** | Polygon ✓ BSC ✓ ETH ✓ | قرارداد امان فریلنسری با داوری | ✅ کامل |
| 🪙 **ReferralToken** | Polygon ✓ BSC ✓ ETH ✓ | توکن ERC20 با سیستم زیرمجموعه‌گیری و وستینگ | ✅ کامل |

---

## ✨ ویژگی‌ها

### 🏛️ MultiSigWallet (کیف پول چند امضایی)
- **چند امضا**: ۲ از ۳، ۳ از ۵ و...
- **قفل زمانی**: برداشت‌ها بعد از تأیید، با delay اجرا می‌شن
- **پشتیبانی توکن**: انتقال اتر و ERC20
- **مدیریت امضاکنندگان**: افزودن/حذف امضاکننده
- **اضطراری**: قابلیت توقف (Pause)
- **آپگریدبل**: با UUPS Proxy

### 🤝 Escrow (قرارداد امان فریلنسری)
- **ایجاد معامله**: کارفرما پول رو قفل می‌کنه
- **تحویل پروژه**: فریلنسر لینک تحویلی رو ثبت می‌کنه
- **تأیید**: کارفرما تأیید می‌کنه، پول آزاد میشه
- **داوری**: در صورت اختلاف، داور تعیین می‌کنه
- **پشتیبانی Token**: اتر و ERC20

### 🪙 ReferralToken (توکن با زیرمجموعه‌گیری)
- **ERC20 استاندارد**: با OpenZeppelin
- **سیستم دعوت**: تا ۳ سطح پاداش
- **کارمزد انتقال**: درصدی از هر انتقال به کیف پول پلتفرم می‌ره
- **سوزاندن**: بخشی از کارمزدها می‌سوزه
- **Vesting**: قفل سود برای تیم
- **Mint/Burn**: ضرب و سوزاندن توسط مالک

---

## 🚀 نصب و راه‌اندازی

```bash
# Clone
git clone https://github.com/mamadiezad/persian-smart-contracts.git
cd persian-smart-contracts

# Install dependencies
npm install

# Compile
npm run compile

# Test
npm run test
```

## 🌐 دیپLOY روی شبکه‌های مختلف

```bash
# Polygon
npm run deploy:polygon

# BSC
npm run deploy:bsc

# Ethereum
npm run deploy:ethereum
```

## 🔄 آپگرید کردن قرارداد

```bash
# بعد از تغییر کد، آپگرید کنید
npm run upgrade
```

---

## 📁 ساختار پروژه

```
persian-smart-contracts/
├── contracts/
│   ├── wallet/
│   │   └── MultiSigWallet.sol    # کیف پول چند امضایی
│   ├── escrow/
│   │   └── Escrow.sol            # قرارداد امان
│   ├── token/
│   │   └── ReferralToken.sol     # توکن با referral
│   └── proxy/
│       └── ProxyControllers.sol  # کنترل‌کننده‌های proxy
├── scripts/
│   ├── deploy.ts                 # استقرار اولیه
│   └── upgrade.ts                # آپگرید قرارداد
├── hardhat.config.ts
├── package.json
└── README.md
```

---

## 🔗 ریپوهای مرتبط

- [🤖 AI Business Sales Bot](https://github.com/mamadiezad/ai-business-sales-bot)
- [🤖 ربات چت ناشناس](https://github.com/mamadiezad/robot-chat-nashnas)
- [📊 MT5 Grid EA](https://github.com/mamadiezad/mt5-grid-trading-ea)

---

## 📜 لایسنس

**MIT**

---

<p align="center">ساخته شده با ❤️ توسط <a href="https://github.com/mamadiezad">Mohammad</a></p>
