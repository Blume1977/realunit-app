# App Screens

Complete inventory of every screen in the RealUnit wallet app — one row per screen.

The source of truth for navigable screens is the `GoRouter` definition in
`lib/setup/routing/router_config.dart`; route names live in
`lib/setup/routing/routes/`. Keep this file in sync when routes, screen widgets
or handbook screenshots change.

Column meaning:

- **Route** / **Path** — the `GoRoute` name and path. `—` means the screen is
  **not a route**: it is shown inside a parent route (KYC steps, status
  sub-pages, disclaimer steps).
- **Handbook** — the handbook screenshot slot number(s) that document the
  screen, or `—` for an orchestrator without its own screenshot (child pages
  still have Visual-Regression Goldens). Each slot is a
  Visual-Regression Golden under `test/goldens/`, mapped to its handbook
  position by `scripts/assemble-handbook-screenshots.sh`. The handbook now
  has a slot for every macOS golden, 418 of them — screens plus their
  state variants (Default / Loading / Error / Snackbar / Dropdown /
  Validation / Confirm / Success / Failure …), including Support (email
  capture, tickets, chat), Settings User-Data and its edit sub-pages,
  Settings Security, Receive, the BitBox hardware-pairing flow
  (`ConnectBitboxPage`, `BitboxAddressRecoveryPage`), the Buy
  payment-details tabs, the full KYC detail states (registration
  personal/address/tax steps, nationality, e-mail, 2FA, ident, financial
  data, link-wallet, signature-unsupported, manual-review, account-merge)
  and `debugAuth` (a `kDebugMode`-only dev tool). Each row lists **all** the
  slots whose Golden renders that widget — a screen usually has several (its
  default plus its state variants), so most cells now carry a range rather
  than a single anchor. Shared-widget goldens rather than screens: slot
  `268` is `PhoneNumberField` under `test/goldens/widgets/form/`, and slot
  `393` is `ImageSourceSheet`. `WebViewPage` is slots `394` and `395` (the
  chrome; the page body is the website and is not part of the picture).
  `PayScanPage` is `338`. `PayProcessPage` is `332`–`334`. `KycPageManager`
  (the orchestrator has no Golden of its own — its states are the
  individual KYC pages) carries `—`. Slot ↔ Golden mapping in
  `scripts/assemble-handbook-screenshots.sh`, slot ↔ HTML block in
  `docs/handbook/de/index.html`. See `docs/handbook/README.md`.

| Area | Widget | Route | Path | Handbook |
|---|---|---|---|---|
| Startup | `StartupFailurePage` | — | — | `377`, `378`, `379`, `380` |
| Startup | `UpdateRequiredPage` | `updateRequired` | `/updateRequired` | `389`, `390`, `391`, `392` |
| Onboarding | `HomePage` | `home` | `/home` | `01`, `11` |
| Onboarding | `WelcomePage` | `welcome` | `/welcome` | `02`, `03`, `62` |
| Onboarding | `CreateWalletPage` | `createWallet` | `/createWallet` | `04`, `05`, `63` |
| Onboarding | `VerifySeedPage` | `verifySeed` | `/verifySeed` | `06`, `34`, `64`, `65`, `66`, `67`, `68` |
| Onboarding | `RestoreWalletPage` | `restoreWallet` | `/restoreWallet` | `25`, `32`, `33`, `69`, `70`, `71`, `72` |
| Onboarding | `OnboardingCompletedPage` | `onboardingCompleted` | `/onboardingComplete` | `07` |
| Onboarding | `DebugAuthPage` | `debugAuth` | `/debugAuth` | `262`, `263`, `264`, `265`, `266`, `267` |
| PIN & lock | `VerifyPinPage` | `pinGate` | `/pinGate` | `17`, `76`, `77`, `78`, `79`, `80`, `81`, `82`, `83`, `84`, `85`, `88` |
| PIN & lock | `SetupPinPage` | `setupPin` | `/setupPin` | `08`, `09`, `10`, `73`, `74`, `75` |
| PIN & lock | `VerifyPinPage` | `verifyPin` | `/verifyPin` | `86`, `87`, `339` |
| Dashboard & trading | `DashboardPage` | `dashboard` | `/dashboard` | `35`, `89`, `90`, `91`, `92`, `93`, `94`, `269`, `289`, `291`, `292`, `308`, `309`, `310`, `311`, `312`, `313`, `314`, `315`, `316`, `317`, `318`, `319`, `320`, `321`, `322`, `340`, `341`, `342`, `387`, `388`, `396` |
| Dashboard & trading | `TransactionHistoryPage` | `transactionHistory` | `/dashboard/transactionHistory` | `36`, `95`, `96`, `97`, `98`, `99`, `100`, `288`, `384`, `385`, `386` |
| Dashboard & trading | `PendingTransactionDetailPage` | `transactionDetail` | `/dashboard/transactionDetail` | `397`, `398` |
| Dashboard & trading | `TransactionDetailPage` | `transactionDetail` | `/dashboard/transactionDetail` | `399`, `400`, `401`, `402`, `403` |
| Dashboard & trading | `BuyPage` | `buy` | `/buy` | `44`, `45`, `46`, `47`, `48`, `103`, `104`, `105`, `106`, `107`, `108`, `109`, `110`, `111`, `112`, `113`, `304`, `305`, `306`, `307` |
| Dashboard & trading | `BuyPaymentDetailsPage` | `buyPaymentDetails` | `/buyPaymentDetails` | `53`, `114`, `115`, `116`, `117` |
| Dashboard & trading | `SellPage` | `sell` | `/sell` | `49`, `50`, `51`, `52`, `118`, `119`, `120`, `123`, `124`, `125`, `359`, `360`, `361`, `362` |
| Dashboard & trading | `SellBitboxPage` | `sellBitbox` | `/sellBitbox` | `126`, `127`, `128`, `129`, `130`, `131`, `132`, `133`, `134`, `135`, `136`, `363`, `364`, `365`, `366` |
| Dashboard & trading | `SellBankAccountSelectionPage` | — | — | `121`, `122` |
| Dashboard & trading | `ReceivePage` | `receive` | `/receive` | `101`, `102`, `296`, `297` |
| Dashboard & trading | `PayInfoPage` | `pay` | `/pay` | `300` |
| Dashboard & trading | `SendInfoPage` | `send` | `/send` | `373` |
| Dashboard & trading | `SendRecipientPage` | — | — | `375` |
| Dashboard & trading | `SendAmountPage` | — | — | `367`, `368`, `370`, `371`, `372` |
| Dashboard & trading | `SendConfirmPage` | — | — | `369` |
| Dashboard & trading | `SendProcessPage` | — | — | `374`, `404` |
| Dashboard & trading | `PayScanPage` | — | — | `338` |
| Dashboard & trading | `PayQuotePage` | — | — | `301`, `302`, `335`, `336`, `337` |
| Dashboard & trading | `PayProcessPage` | — | — | `332`, `333`, `334` |
| Dashboard & trading | `ConnectBitboxPage` | — | — | `137`, `138`, `139`, `140`, `141`, `142`, `143`, `144`, `145`, `146` |
| Dashboard & trading | `BitboxAddressRecoveryPage` | `bitboxAddressRecovery` | `/bitboxAddressRecovery` | `147` |
| Dashboard & trading | `WebViewPage` | `webView` | `/webView` | `394`, `395` |
| Legal | `LegalDisclaimerPage` | `legalDisclaimer` | `/legalDisclaimer` | `242` |
| Legal | `LegalDocumentPage` | `legalDocument` | `/legalDocument` | `243`, `244`, `245` |
| Legal | `LegalDocumentPage` | `terms` | `/termsOfUse` | `26` |
| Legal | `LegalDisclaimerStep` | — | — | `27`, `28` |
| Legal | `LegalDfxStep` | — | — | `31` |
| Legal | `LegalAktionariatStep` | — | — | `30` |
| Legal | `LegalDocumentsStep` | — | — | `29` |
| Settings | `SettingsPage` | `settings` | `/settings` | `12`, `24`, `211`, `212`, `285`, `293`, `299`, `376` |
| Settings | `SettingsAktionariatDocumentsPage` | `settingsAktionariatDocuments` | `/settings/aktionariatDocuments` | `21` |
| Settings | `SettingsContactPage` | `settingsContact` | `/settings/contact` | `23` |
| Settings | `SettingsCurrenciesPage` | `settingsCurrencies` | `/settings/currencies` | `14`, `215`, `216` |
| Settings | `SettingsDfxDocumentsPage` | `settingsDfxDocuments` | `/settings/dfxDocuments` | `22` |
| Settings | `SettingsLanguagePage` | `settingsLanguages` | `/settings/languages` | `13`, `213`, `214` |
| Settings | `SettingsLegalDocumentsPage` | `settingsLegalDocuments` | `/settings/legalDocuments` | `20`, `286` |
| Settings | `SettingsNetworkPage` | `settingsNetwork` | `/settings/network` | `15`, `217` |
| Settings | `SettingsSecurityPage` | `settingsSecurity` | `/settings/security` | `219`, `220`, `221`, `222`, `223` |
| Settings | `SettingsTaxReportPage` | `settingsTaxReport` | `/settings/taxReport` | `42`, `43`, `224`, `225`, `226` |
| Settings | `SettingsSeedPage` | `settingsSeed` | `/settings/seed` | `18`, `19`, `218` |
| Settings | `SettingsWalletAddressPage` | `settingsWalletAddress` | `/settings/walletAddress` | `16`, `298` |
| Settings | `SettingsInsiderPage` | `settingsInsider` | `/settings/insider` | `294`, `295` |
| Settings | `ReferralPage` | `settingsReferral` | `/settings/referral` | `279`, `348`, `349`, `350` |
| Settings | `ReferralCreatePage` | `settingsReferralCreate` | `/settings/referral/create` | `280`, `284`, `343`, `344`, `345`, `346`, `347`, `405`, `406`, `407` |
| Settings | `ReferralOverviewPage` | — | — | `276`, `351`, `352`, `353`, `354`, `355`, `408`, `409` |
| Settings | `ReferralTermsPage` | `referralTerms` | `/referralTerms` | `281`, `283`, `358` |
| Settings | `SettingsUserDataPage` | `settingsUserData` | `/settings/userData` | `227`, `228`, `229`, `230`, `231`, `232`, `233`, `234`, `235` |
| Settings | `SettingsEditNamePage` | `settingsEditName` | `/settings/userData/editName` | `236` |
| Settings | `SettingsEditAddressPage` | `settingsEditAddress` | `/settings/userData/editAddress` | `238` |
| Settings | `SettingsEditPhoneNumberPage` | `settingsEditPhone` | `/settings/userData/editPhoneNumber` | `237` |
| Settings | `SettingsEditLoadingPage` | — | — | `239` |
| Settings | `SettingsEditPendingPage` | — | — | `240` |
| Settings | `SettingsEditFailurePage` | — | — | `241` |
| Support | `SupportPage` | `support` | `/support` | `246` |
| Support | `SupportEmailCapturePage` | `supportEmailCapture` | `/support/email` | `247`, `248`, `249` |
| Support | `SupportTicketsPage` | `supportTickets` | `/support/tickets` | `253`, `254`, `255`, `256` |
| Support | `SupportCreateTicketPage` | `supportCreateTicket` | `/support/create` | `250`, `251`, `252`, `381`, `382`, `383` |
| Support | `SupportChatPage` | `supportChat` | `/support/chat/:uid` | `257`, `258`, `259`, `260`, `261` |
| KYC | `KycPageManager` | `kyc` | `/kyc` | — |
| KYC | `KycRegistrationPage` | — | — | `161`, `162`, `166`, `168`, `169`, `170`, `171`, `172`, `326` |
| KYC | `KycUnsupportedStepPage` | — | — | `331` |
| KYC | `KycRegistrationReferralStep` | — | — | `277`, `287`, `290`, `327`, `328`, `329`, `330` |
| KYC | `KycRegistrationPersonalStep` | — | — | `40`, `54`, `163`, `164`, `165` |
| KYC | `KycPersonalDataPage` | — | — | `324`, `325` |
| KYC | `KycRegistrationAddressStep` | — | — | `41`, `55`, `167` |
| KYC | `KycRegistrationTaxStep` | — | — | `56`, `57`, `58`, `59`, `60`, `61`, `61b`, `61c`, `61d`, `61e`, `61f`, `61g`, `61h`, `61i`, `61j`, `61k` |
| KYC | `KycNationalityPage` | — | — | `173`, `174`, `175`, `176`, `177`, `178`, `179` |
| KYC | `KycEmailPage` | — | — | `37`, `38`, `39`, `148`, `149`, `150` |
| KYC | `KycEmailVerificationPage` | — | — | `152`, `153`, `154`, `155` |
| KYC | `KycConfirmEmailPage` | — | — | `151` |
| KYC | `Kyc2faPage` | — | — | `156`, `157`, `158`, `159`, `160` |
| KYC | `KycIdentPage` | — | — | `193`, `194`, `195`, `196` |
| KYC | `KycLinkWalletPage` | — | — | `197`, `198`, `199`, `200`, `201`, `202` |
| KYC | `KycSignatureUnsupportedPage` | — | — | `203` |
| KYC | `KycFinancialDataPage` | — | — | `180`, `182`, `184` |
| KYC | `KycFinancialDataQuestionsPage` | — | — | `185`, `186`, `187`, `188`, `189`, `190`, `191`, `192` |
| KYC | `KycFinancialDataLoadingPage` | — | — | `181` |
| KYC | `KycFinancialDataFailurePage` | — | — | `183` |
| KYC | `KycLoadingPage` | — | — | `204` |
| KYC | `KycPendingPage` | — | — | `205` |
| KYC | `KycCompletedPage` | — | — | `206` |
| KYC | `KycFailurePage` | — | — | `207` |
| KYC | `KycManualReviewPage` | — | — | `208`, `323` |
| KYC | `KycAccountMergePage` | — | — | `209` |
| KYC | `KycMergeProcessingPage` | — | — | `210` |
| Shared widgets | `PhoneNumberField` | — | — | `268` |
| Shared widgets | `ImageSourceSheet` | — | — | `393` |
| Shared widgets | `ReferralPayoutTransactionRow` | — | — | `282`, `356`, `357` |

95 screens — 51 routed (`GoRoute`) + 44 non-routed. The table also carries
three shared-widget baselines (`PhoneNumberField`, `ReferralPayoutTransactionRow`, `ImageSourceSheet`),
which are not screens.
Referral surfaces have Golden baselines (`276`–`292`); the handbook
documents the programme in `#spec-referral`. Overlay slots `291` and `292`
are listed on `DashboardPage` (the host screen), not as a second shared-widget
row. OpenCryptoPay pay rounding cards `300`–`302` are documented in
`#spec-81`.

## Notes

- **Non-routed screens** are driven inside a parent route: the KYC pages are
  orchestrated by `KycPageManager` under `/kyc`; the `*Step` widgets are steps
  inside a parent (`LegalDisclaimerStep` etc. inside `LegalDisclaimerPage`,
  `KycRegistration*Step` inside `KycRegistrationPage`); the `*Loading` /
  `*Pending` / `*Failure` pages are operation-status screens.
- **`debugAuth`** is registered only in debug builds (`kDebugMode`).
- **Shared widgets.** `LegalDocumentPage` backs two routes (`legalDocument`,
  `terms`); `VerifyPinPage` backs two (`pinGate`, `verifyPin`) via different
  constructors. Both uses are now documented and the slots are split between
  the rows: `VerifyPinPage`'s `pinGate` use is slots `17`, `76`–`85`, `88`
  and its `verifyPin` app-lock use is slots `86`, `87`, `339`; `LegalDocumentPage`'s
  `terms` route is slot `26` and its generic `legalDocument` route is slots
  `243`–`245`. `SetupPinPage` also backs the `settingsChangePin` route
  (`/settings/security/changePin`) via a second constructor; that reuse has no
  separate Golden and is not given its own row.
- **Handbook numbering.** Each of the 418 handbook slots is a Visual-Regression
  Golden under `test/goldens/`, mapped to its handbook position by
  `scripts/assemble-handbook-screenshots.sh`. A parallel Tier-3 Maestro flow
  (`.maestro/handbook/NN-*.yaml`) covers navigation/tap-routing smoke for the
  routed screens but does not produce the handbook image. Modal sheets are
  attached to the screen they belong to: slot `10` (`biometric_prompt_sheet`,
  the `EnableBiometricBottomSheet`) sits on `SetupPinPage`, slot `88`
  (`forgot_pin_bottom_sheet`) on the `pinGate` `VerifyPinPage`, slots `24` and
  `212` (`settings_confirm_logout_wallet_sheet`) on `SettingsPage`, slot `122`
  (`sell_add_bank_account_sheet`) on `SellBankAccountSelectionPage`, and slots
  `123`–`125` (the sell confirm/executed sheets) on `SellPage`.
- **`*Page` / `*View` pattern.** Several screens split into a `*Page` widget
  (provides the bloc/cubit) and a `*View` widget (builds the `Scaffold`):
  `CreateWalletView`, `RestoreWalletView`, `SettingsSeedView`, `DebugAuthView`.
  These are not separate screens — each belongs to its `*Page`.
- **Modal presentation.** Several of these widgets are shown modally rather
  than as routed screens, but they still have Golden baselines, so they appear
  in the table attached to (or as) their nearest screen: `EnableBiometricBottomSheet`
  (slot `10`, on `SetupPinPage`) and the sell / logout / forgot-pin sheets.
  `ConnectBitboxPage` — despite its `Page` suffix it builds no `Scaffold` and is
  shown via `showModalBottomSheet` — has enough Goldens (the full pairing flow,
  slots `137`–`146`) to warrant its own row. `ReceivePage` in `isBottomSheet`
  mode reuses the routed `ReceivePage` widget (slots `101`, `102`).
