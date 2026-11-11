import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[Locale('en'), Locale('my')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  String text(String key) {
    final values = locale.languageCode == 'my' ? _my : _en;
    return values[key] ?? _en[key] ?? key;
  }

  String translate(String source) {
    if (locale.languageCode != 'my') return source;
    return _myLabels[source] ?? source;
  }

  static const _myLabels = <String, String>{
    'Dashboard': 'ပင်မစာမျက်နှာ',
    'Quotes': 'ဈေးနှုန်းလွှာများ',
    'Orders': 'အော်ဒါများ',
    'Customers': 'ဖောက်သည်များ',
    'More': 'နောက်ထပ်',
    'Finance': 'ငွေကြေးစီမံခန့်ခွဲမှု',
    'Products': 'ကုန်ပစ္စည်းများ',
    'Materials': 'ကုန်ကြမ်းများ',
    'Expenses': 'အသုံးစရိတ်များ',
    'Cash ledger': 'ငွေစာရင်း',
    'Sales report': 'အရောင်းအစီရင်ခံစာ',
    'Profitability': 'အမြတ်အစွန်း',
    'Receivables': 'ရရန်ငွေ',
    'Quotation': 'ဈေးနှုန်းလွှာ',
    'Quotations': 'ဈေးနှုန်းလွှာများ',
    'Order': 'အော်ဒါ',
    'Customer': 'ဖောက်သည်',
    'Account': 'အကောင့်',
    'Business': 'လုပ်ငန်း',
    'Business settings': 'လုပ်ငန်းဆက်တင်များ',
    'Team': 'အဖွဲ့',
    'New': 'အသစ်',
    'New quotation': 'ဈေးနှုန်းလွှာအသစ်',
    'New order': 'အော်ဒါအသစ်',
    'New customer': 'ဖောက်သည်အသစ်',
    'New product': 'ကုန်ပစ္စည်းအသစ်',
    'New material': 'ကုန်ကြမ်းအသစ်',
    'Edit order': 'အော်ဒါပြင်ဆင်ရန်',
    'Edit quotation': 'ဈေးနှုန်းလွှာပြင်ဆင်ရန်',
    'Edit customer': 'ဖောက်သည်ပြင်ဆင်ရန်',
    'Edit product': 'ကုန်ပစ္စည်းပြင်ဆင်ရန်',
    'Edit material': 'ကုန်ကြမ်းပြင်ဆင်ရန်',
    'Name': 'အမည်',
    'Full name': 'အမည်အပြည့်အစုံ',
    'Display name': 'ပြသမည့်အမည်',
    'Email': 'အီးမေးလ်',
    'Password': 'စကားဝှက်',
    'Confirm password': 'စကားဝှက်အတည်ပြုရန်',
    'Phone': 'ဖုန်းနံပါတ်',
    'Address': 'လိပ်စာ',
    'Description': 'ဖော်ပြချက်',
    'Notes': 'မှတ်ချက်များ',
    'Reference': 'ရည်ညွှန်းနံပါတ်',
    'Amount': 'ငွေပမာဏ',
    'Quantity': 'အရေအတွက်',
    'Qty': 'အရေအတွက်',
    'Unit': 'ယူနစ်',
    'Unit price': 'တစ်ယူနစ်ဈေးနှုန်း',
    'Unit cost': 'တစ်ယူနစ်ကုန်ကျစရိတ်',
    'Base price': 'အခြေခံဈေးနှုန်း',
    'Customer since': 'ဖောက်သည်ဖြစ်သည့်နေ့',
    'Status': 'အခြေအနေ',
    'Category': 'အမျိုးအစား',
    'Method': 'ငွေပေးချေမှုနည်းလမ်း',
    'Assigned to': 'တာဝန်ပေးထားသူ',
    'Discount type': 'လျှော့ဈေးအမျိုးအစား',
    'Role': 'တာဝန်',
    'Business name': 'လုပ်ငန်းအမည်',
    'Currency code': 'ငွေကြေးကုဒ်',
    'Subtotal': 'စုစုပေါင်းခွဲ',
    'Discount': 'လျှော့ဈေး',
    'Total': 'စုစုပေါင်း',
    'Revenue': 'ဝင်ငွေ',
    'Profit': 'အမြတ်',
    'Production cost': 'ထုတ်လုပ်မှုကုန်ကျစရိတ်',
    'Operating expenses': 'လုပ်ငန်းအသုံးစရိတ်',
    'Gross profit': 'အကြမ်းအမြတ်',
    'Outstanding': 'ကျန်ရှိရရန်ငွေ',
    'Overdue': 'သတ်မှတ်ရက်ကျော်',
    'Delivered': 'ပို့ဆောင်ပြီး',
    'Save product': 'ကုန်ပစ္စည်းသိမ်းရန်',
    'Save material': 'ကုန်ကြမ်းသိမ်းရန်',
    'Save customer': 'ဖောက်သည်သိမ်းရန်',
    'Save quotation': 'ဈေးနှုန်းလွှာသိမ်းရန်',
    'Save order': 'အော်ဒါသိမ်းရန်',
    'Save payment': 'ငွေပေးချေမှုသိမ်းရန်',
    'Save expense': 'အသုံးစရိတ်သိမ်းရန်',
    'Save cost': 'ကုန်ကျစရိတ်သိမ်းရန်',
    'Save settings': 'ဆက်တင်များသိမ်းရန်',
    'Save profile': 'ကိုယ်ရေးအချက်အလက်သိမ်းရန်',
    'Sign in': 'အကောင့်ဝင်ရန်',
    'Sign out': 'အကောင့်ထွက်ရန်',
    'Create account': 'အကောင့်ဖွင့်ရန်',
    'Reset password': 'စကားဝှက်ပြန်လည်သတ်မှတ်ရန်',
    'Add product': 'ကုန်ပစ္စည်းထည့်ရန်',
    'Add material': 'ကုန်ကြမ်းထည့်ရန်',
    'Add customer': 'ဖောက်သည်ထည့်ရန်',
    'Add line': 'စာကြောင်းထည့်ရန်',
    'From catalog': 'ကုန်ပစ္စည်းစာရင်းမှ',
    'Record expense': 'အသုံးစရိတ်မှတ်တမ်းတင်ရန်',
    'Print / save as PDF': 'PDF ပုံနှိပ်ရန် / သိမ်းရန်',
    'Share PDF': 'PDF မျှဝေရန်',
    'Record': 'မှတ်တမ်းတင်ရန်',
    'Add': 'ထည့်ရန်',
    'Refund': 'ပြန်အမ်းရန်',
    'Void': 'ပယ်ဖျက်ရန်',
    'Remove': 'ဖယ်ရှားရန်',
    'Cancel': 'မလုပ်တော့ပါ',
    'Create': 'ဖန်တီးရန်',
    'Invite': 'ဖိတ်ခေါ်ရန်',
    'Try again': 'ထပ်မံကြိုးစားရန်',
    'Active': 'အသုံးပြုနေသည်',
    'Active customer': 'အသုံးပြုနေသောဖောက်သည်',
    'Date': 'ရက်စွဲ',
    'Paid on': 'ပေးချေသည့်ရက်',
    'Valid until': 'သက်တမ်းကုန်ရက်',
    'Due date': 'ပေးချေရမည့်ရက်',
    'Cost date': 'ကုန်ကျစရိတ်ရက်စွဲ',
    'Change': 'ပြောင်းရန်',
    'Pick': 'ရွေးရန်',
    'None': 'မရှိ',
    'Nobody': 'မည်သူမျှမဟုတ်',
    'Percent': 'ရာခိုင်နှုန်း',
    'Cash': 'လက်ငင်းငွေ',
    'Bank transfer': 'ဘဏ်လွှဲ',
    'Permission denied': 'အသုံးပြုခွင့်မရှိပါ',
    'Something went wrong': 'တစ်ခုခုမှားယွင်းနေပါသည်',
    'Customer not found': 'ဖောက်သည်မတွေ့ပါ',
    'Draft': 'မူကြမ်း',
    'Confirmed': 'အတည်ပြုပြီး',
    'In production': 'ထုတ်လုပ်နေဆဲ',
    'On hold': 'ခေတ္တရပ်ထား',
    'Completed': 'ပြီးစီးပြီ',
    'Closed': 'ပိတ်ပြီး',
    'Cancelled': 'ပယ်ဖျက်ပြီး',
    'Sent': 'ပို့ပြီး',
    'Accepted': 'လက်ခံပြီး',
    'Rejected': 'ငြင်းပယ်ပြီး',
    'Expired': 'သက်တမ်းကုန်ပြီ',
    'Converted': 'ပြောင်းလဲပြီး',
    'Owner': 'ပိုင်ရှင်',
    'Staff': 'ဝန်ထမ်း',
    'Accountant': 'စာရင်းကိုင်',
    'Your businesses': 'သင့်လုပ်ငန်းများ',
    'New business': 'လုပ်ငန်းအသစ်',
    'Invite a team member': 'အဖွဲ့ဝင်ဖိတ်ခေါ်ရန်',
    'Forgot password?': 'စကားဝှက်မေ့နေပါသလား။',
    'No account yet?': 'အကောင့်မရှိသေးပါသလား။',
    'Create one': 'အကောင့်ဖွင့်မည်',
    'Already registered?': 'အကောင့်ရှိပြီးသားလား။',
    'Outstanding balance and ageing': 'ကျန်ငွေနှင့် သက်တမ်းအလိုက်စာရင်း',
    'Revenue, cash collected and order mix':
        'ဝင်ငွေ၊ ကောက်ခံငွေနှင့် အော်ဒါအမျိုးအစား',
    'Margin per delivered order': 'ပို့ဆောင်ပြီးအော်ဒါတစ်ခုချင်း အမြတ်နှုန်း',
    'Payments and refunds': 'ပေးချေငွေနှင့် ပြန်အမ်းငွေ',
    'Search customers': 'ဖောက်သည်ရှာရန်',
    'Search by number or customer': 'နံပါတ် သို့မဟုတ် ဖောက်သည်ဖြင့်ရှာရန်',
    'Cost type': 'ကုန်ကျစရိတ်အမျိုးအစား',
    'Material': 'ကုန်ကြမ်း',
    'Payment type': 'ငွေပေးချေမှုအမျိုးအစား',
  };

  static const _en = <String, String>{
    'dashboard': 'Dashboard',
    'quotes': 'Quotes',
    'orders': 'Orders',
    'customers': 'Customers',
    'more': 'More',
    'catalog': 'Catalog',
    'products': 'Products',
    'materials': 'Materials',
    'money': 'Money',
    'cash_ledger': 'Cash ledger',
    'expenses': 'Expenses',
    'reports': 'Reports',
    'reports_subtitle': 'Sales, profitability, receivables',
    'business': 'Business',
    'team': 'Team',
    'business_settings': 'Business settings',
    'preferences': 'Preferences',
    'language': 'Language',
    'choose_language': 'Choose language',
    'english': 'English',
    'myanmar': 'Myanmar',
    'account': 'Account',
    'profile': 'Profile',
    'sign_out': 'Sign out',
    'signed_in': 'Signed in',
  };

  static const _my = <String, String>{
    'dashboard': 'ပင်မစာမျက်နှာ',
    'quotes': 'ဈေးနှုန်းလွှာများ',
    'orders': 'အော်ဒါများ',
    'customers': 'ဖောက်သည်များ',
    'more': 'နောက်ထပ်',
    'catalog': 'ကုန်ပစ္စည်းစာရင်း',
    'products': 'ကုန်ပစ္စည်းများ',
    'materials': 'ကုန်ကြမ်းများ',
    'money': 'ငွေကြေး',
    'cash_ledger': 'ငွေစာရင်း',
    'expenses': 'အသုံးစရိတ်များ',
    'reports': 'အစီရင်ခံစာများ',
    'reports_subtitle': 'အရောင်း၊ အမြတ်အစွန်းနှင့် ရရန်ငွေ',
    'business': 'လုပ်ငန်း',
    'team': 'အဖွဲ့',
    'business_settings': 'လုပ်ငန်းဆက်တင်များ',
    'preferences': 'နှစ်သက်ရာဆက်တင်များ',
    'language': 'ဘာသာစကား',
    'choose_language': 'ဘာသာစကားရွေးချယ်ပါ',
    'english': 'အင်္ဂလိပ်',
    'myanmar': 'မြန်မာ',
    'account': 'အကောင့်',
    'profile': 'ကိုယ်ရေးအချက်အလက်',
    'sign_out': 'အကောင့်ထွက်ရန်',
    'signed_in': 'အကောင့်ဝင်ထားသည်',
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'my';

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
