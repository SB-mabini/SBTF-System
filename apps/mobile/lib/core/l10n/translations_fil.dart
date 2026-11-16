/// Filipino translations for the driver app's fixed front-end chrome.
///
/// This file is deliberately data-only: it maps complete English UI strings to
/// their Filipino equivalent. [translateToFilipino] first looks for an exact
/// match, then falls back to longest-phrase replacement so interpolated strings
/// such as `Accepted 12 Nov 2026` still translate their fixed words.
///
/// Server-provided content (announcements, remarks, venues, names) is not in
/// this map and is rendered with translation disabled at those call sites.
library;

/// Normalises typography so dictionary keys can be written in plain ASCII.
String _normalize(String source) => source
    .replaceAll('\u2019', "'")
    .replaceAll('\u2018', "'")
    .replaceAll('\u201c', '"')
    .replaceAll('\u201d', '"')
    .replaceAll('\u2013', '-')
    .replaceAll('\u2014', '-')
    .replaceAll('\u2026', '...')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Exact English → Filipino strings.
const Map<String, String> filipinoTranslations = <String, String>{
  // ── Navigation and section chrome ─────────────────────────────────────────
  'Home': 'Tahanan',
  'Apply': 'Mag-apply',
  'Track': 'Subaybayan',
  'Documents': 'Mga Dokumento',
  'Settings': 'Mga Setting',
  'Notifications': 'Mga Abiso',
  'Announcements': 'Mga Anunsyo',
  'Applications': 'Mga Aplikasyon',
  'Appointments': 'Mga Appointment',
  'Appointment': 'Appointment',
  'Application': 'Aplikasyon',
  'Certificate': 'Sertipiko',
  'Certificate & QR': 'Sertipiko at QR',
  'Certificate & QR Code': 'Sertipiko at QR Code',
  'Certificate &QR': 'Sertipiko at QR',
  'Profile': 'Profile',
  'Account': 'Account',
  'Details': 'Detalye',
  'History': 'Kasaysayan',
  'Manage': 'Pamahalaan',
  'View': 'Tingnan',
  'Open': 'Buksan',
  'Close': 'Isara',
  'Cancel': 'Kanselahin',
  'Delete': 'Burahin',
  'Update': 'I-update',
  'Replace': 'Palitan',
  'Retry': 'Subukan muli',
  'Refresh': 'I-refresh',
  'Done': 'Tapos na',
  'Back': 'Bumalik',
  'Next': 'Susunod',
  'Continue': 'Magpatuloy',
  'Skip': 'Laktawan',
  'Later': 'Mamaya',
  'Keep it': 'Itago',
  'Clear': 'I-clear',
  'Save': 'I-save',
  'Submit': 'Isumite',
  'Accept': 'Tanggapin',
  'Try again': 'Subukan muli',
  'Please wait': 'Maghintay sandali',
  'Loading...': 'Naglo-load...',
  'N/A': 'Wala',
  'Type': 'Uri',
  'Status': 'Katayuan',
  'Name': 'Pangalan',
  'Address': 'Tirahan',
  'Contact': 'Kontak',
  'Contact number': 'Numero ng kontak',
  'E-mail': 'E-mail',
  'E-mail address': 'E-mail address',
  'E-mail (optional)': 'E-mail (opsyonal)',
  'Password': 'Password',
  'New password': 'Bagong password',
  'Confirm password': 'Kumpirmahin ang password',
  'Confirm new password': 'Kumpirmahin ang bagong password',
  'Current password': 'Kasalukuyang password',
  'Language': 'Wika',
  'English': 'English',
  'Filipino': 'Filipino',
  'Hello': 'Kumusta',
  'Welcome': 'Maligayang pagdating',
  'Log out': 'Mag-logout',
  'Log Out': 'Mag-logout',
  'Sign out': 'Mag-sign out',
  'Sign in': 'Mag-sign in',
  'Login': 'Mag-login',
  'Create account': 'Gumawa ng account',
  'Create your account': 'Gumawa ng iyong account',
  'Register Now': 'Magrehistro Ngayon',
  'Back to sign in': 'Bumalik sa pag-sign in',
  'Forgot password': 'Nakalimutan ang password',
  'Forgot your password?': 'Nakalimutan mo ang password?',
  'Reset your password': 'I-reset ang password',
  'Set a new password': 'Magtakda ng bagong password',
  'Send reset code': 'Ipadala ang reset code',
  'Save password and continue': 'I-save ang password at magpatuloy',
  'Sign into your Account': 'Mag-sign in sa iyong Account',

  // ── Statuses and outcomes ─────────────────────────────────────────────────
  'Active': 'Aktibo',
  'Inactive': 'Hindi aktibo',
  'Approved': 'Naaprubahan',
  'Rejected': 'Tinanggihan',
  'Pending': 'Nakabinbin',
  'Pending review': 'Nakabinbin sa pagsusuri',
  'Waiting for staff approval': 'Naghihintay ng pag-apruba ng staff',
  'Expired': 'Nag-expire',
  'Expiring soon': 'Malapit nang mag-expire',
  'Valid': 'Wasto',
  'Valid until': 'Wasto hanggang',
  'Verified': 'Na-verify',
  'Scheduled': 'Nakatakda',
  'Completed': 'Kumpleto',
  'Cancelled': 'Kinansela',
  'No show': 'Hindi sumipot',
  'Rescheduled': 'Na-reschedule',
  'Submitted': 'Isinumite',
  'Reviewed': 'Nasuri',
  'Archived': 'Naka-archive',
  'Uploaded': 'Na-upload',
  'New': 'Bago',
  'New franchise': 'Bagong prangkisa',
  'Renewal': 'Pag-renew',
  'Renew': 'I-renew',
  'Upcoming': 'Nalalapit',
  'Past': 'Nakaraan',

  // ── Home ──────────────────────────────────────────────────────────────────
  'Welcome back': 'Maligayang pagbabalik',
  'Track & Updates': 'Subaybayan at Mga Update',
  'Documents & Certificates': 'Mga Dokumento at Sertipiko',
  'My Appointments': 'Aking mga Appointment',
  'Scheduled visits and hearings': 'Mga nakatakdang pagbisita at pagdinig',
  'My Application Status': 'Status ng Aking Aplikasyon',
  'Follow your submissions': 'Subaybayan ang iyong mga submission',
  'Notices from the franchising office':
      'Mga abiso mula sa tanggapan ng prangkisa',
  'Decisions, reminders and updates': 'Mga desisyon, paalala at update',
  'My Documents': 'Aking mga Dokumento',
  'My documents': 'Aking mga dokumento',
  'Manage your uploaded files': 'Pamahalaan ang iyong mga na-upload na file',
  'View your franchise certificate':
      'Tingnan ang iyong sertipiko ng prangkisa',
  'View application': 'Tingnan ang aplikasyon',
  'Application details': 'Detalye ng aplikasyon',
  'No application yet': 'Wala pang aplikasyon',
  'No applications yet': 'Wala pang aplikasyon',
  'Start a new application': 'Magsimula ng bagong aplikasyon',
  'Start your franchise journey by filing a new application.':
      'Simulan ang iyong paglalakbay sa prangkisa sa pamamagitan ng paghahain ng bagong aplikasyon.',
  'File a new or renewal application':
      'Maghain ng bago o pag-renew na aplikasyon',
  'Renew an existing franchise': 'I-renew ang umiiral na prangkisa',
  'Renew an existing franchise - previous details are filled in':
      'I-renew ang umiiral na prangkisa - ang mga dating detalye ay awtomatikong nakalagay',
  'Track &amp; Updates': 'Subaybayan at Mga Update',
  'Open application status': 'Buksan ang status ng aplikasyon',
  'No franchise certificate yet': 'Wala pang sertipiko ng prangkisa',
  'Franchise certificate': 'Sertipiko ng prangkisa',
  'Open certificate': 'Buksan ang sertipiko',
  'Check my application': 'Tingnan ang aking aplikasyon',
  'Apply now': 'Mag-apply ngayon',
  'File and track your tricycle franchise application, manage your requirements, and keep your certificate and official updates within reach - from the Municipality of Mabini, Batangas.':
      'Ihain at subaybayan ang iyong aplikasyon sa prangkisa ng traysikel, pamahalaan ang iyong mga kinakailangan, at itago ang iyong sertipiko at mga opisyal na update sa loob ng kamay - mula sa Munisipyo ng Mabini, Batangas.',
  'Once the municipal office approves your application, your franchise certificate and its QR code will appear here.':
      'Kapag naaprubahan ng munisipal na tanggapan ang iyong aplikasyon, lalabas dito ang iyong sertipiko ng prangkisa at ang QR code nito.',
  'When you submit a franchise application it will appear here, with its status and history.':
      'Kapag nagsumite ka ng aplikasyon sa prangkisa, lalabas ito dito kasama ang status at kasaysayan nito.',
  'When the municipal office schedules an evaluation, a hearing or a document-release visit for your application, it will appear here with the date, time and venue.':
      'Kapag nagtakda ang munisipal na tanggapan ng ebalwasyon, pagdinig o pagbisita para sa paglabas ng dokumento para sa iyong aplikasyon, lalabas ito dito kasama ang petsa, oras at lugar.',

  // ── Application list and detail ───────────────────────────────────────────
  'Franchise number': 'Numero ng prangkisa',
  'Plate number': 'Numero ng plaka',
  'Operator': 'Operator',
  'Applicant': 'Aplikante',
  'Driver / Operator': 'Driver / Operator',
  'Vehicle': 'Sasakyan',
  'Vehicle make': 'Tatak ng sasakyan',
  'Vehicle model': 'Modelo ng sasakyan',
  'Vehicle color': 'Kulay ng sasakyan',
  'Engine number': 'Numero ng makina',
  'Chassis number': 'Numero ng tsasis',
  'Body number': 'Numero ng katawan',
  'Body number (optional)': 'Numero ng katawan (opsyonal)',
  'Seating capacity': 'Kapasidad ng upuan',
  'Make': 'Tatak',
  'Model': 'Modelo',
  'Color': 'Kulay',
  'MTOP number': 'Numero ng MTOP',
  'MTOP number (optional)': 'Numero ng MTOP (opsyonal)',
  'CR number': 'Numero ng CR',
  'CTC number': 'Numero ng CTC',
  'CTC / Cedula number': 'Numero ng CTC / Cedula',
  'Citizenship': 'Pagkamamamayan',
  'Type of ownership': 'Uri ng pagmamay-ari',
  'Single proprietorship': 'Nag-iisang may-ari',
  'Cooperative': 'Kooperatiba',
  'Corporation': 'Korporasyon',
  'Registered owner': 'Rehistradong may-ari',
  'First franchise for this tricycle':
      'Unang prangkisa para sa traysikel na ito',
  'Franchise to renew': 'Prangkisang i-renew',
  'Select the franchise to renew': 'Piliin ang prangkisang i-renew',
  'Select the franchise being renewed.':
      'Piliin ang prangkisang nire-renew.',
  'Reference number: ': 'Reference number: ',
  'Submitted on': 'Isinumite noong',
  'Submitted ': 'Isinumite ',
  'Reviewed ': 'Nasuri ',
  'Target review: ': 'Target na pagsusuri: ',
  'Application submitted': 'Naisumite ang aplikasyon',
  'Application not sent': 'Hindi naipadala ang aplikasyon',
  'Application incomplete': 'Hindi kumpleto ang aplikasyon',
  'Application under review': 'Sinusuri ang aplikasyon',
  'This application was rejected': 'Tinanggihan ang aplikasyong ito',
  'This application is ': 'Ang aplikasyong ito ay ',
  '. Documents can only be replaced while it is under review.':
      '. Maaari lamang palitan ang mga dokumento habang sinusuri ito.',
  'Documents incomplete': 'Hindi kumpleto ang mga dokumento',
  'Staff returned your request': 'Ibinalik ng staff ang iyong kahilingan',
  'The municipal office will review your documents. You will be notified here when the status changes.':
      'Susuriin ng munisipal na tanggapan ang iyong mga dokumento. Aabisuhan ka rito kapag nagbago ang status.',
  'These details come from your approved request form and cannot be changed here.':
      'Ang mga detalyeng ito ay mula sa iyong naaprubahang request form at hindi mababago rito.',
  'That application is no longer available.':
      'Hindi na available ang aplikasyong iyon.',
  'No profile found': 'Walang natagpuang profile',
  'Your profile is still loading. Please wait and try again.':
      'Naglo-load pa ang iyong profile. Maghintay at subukan muli.',
  'Your profile is still loading. Please wait.':
      'Naglo-load pa ang iyong profile. Maghintay sandali.',
  'Account not active': 'Hindi aktibo ang account',
  'Account suspended': 'Nasuspinde ang account',
  'Account already exists': 'May account na',
  'Account updated': 'Na-update ang account',
  'Registration failed': 'Nabigo ang pagpaparehistro',
  'Cannot sign in': 'Hindi makapag-sign in',
  'Cannot resend': 'Hindi maipadala muli',
  'Cannot verify': 'Hindi ma-verify',
  'Connection problem': 'Problema sa koneksyon',
  'Upload failed': 'Nabigo ang pag-upload',
  'Request not sent': 'Hindi naipadala ang kahilingan',
  'Could not cancel': 'Hindi makansela',
  'Document not replaced': 'Hindi napalitan ang dokumento',
  'Password not saved': 'Hindi na-save ang password',
  'Code not sent': 'Hindi naipadala ang code',
  'Code not accepted': 'Hindi tinanggap ang code',
  'Configuration required': 'Kinakailangan ang configuration',
  'Supabase is not configured': 'Hindi naka-configure ang Supabase',
  'Use the web console': 'Gamitin ang web console',
  'Preparing your workspace': 'Inihahanda ang iyong workspace',
  'Checking your session...': 'Sinusuri ang iyong session...',

  // ── Forms and validation ──────────────────────────────────────────────────
  'First name': 'Pangalan',
  'Middle name': 'Gitnang pangalan',
  'Middle name (optional)': 'Gitnang pangalan (opsyonal)',
  'Last name': 'Apelyido',
  'Suffix': 'Suffix',
  'Purpose (optional)': 'Layunin (opsyonal)',
  'Barangay': 'Barangay',
  'TODA': 'TODA',
  'Select your TODA': 'Piliin ang iyong TODA',
  'Choose your TODA': 'Piliin ang iyong TODA',
  'Choose your barangay': 'Piliin ang iyong barangay',
  'Application type': 'Uri ng aplikasyon',
  'Please check this': 'Pakisuri ito',
  'Enter a valid e-mail address.': 'Maglagay ng wastong e-mail address.',
  'Enter a strong password': 'Maglagay ng matibay na password',
  'Enter your password': 'Ilagay ang iyong password',
  'Enter your password.': 'Ilagay ang iyong password.',
  'At least 8 characters': 'Hindi bababa sa 8 character',
  'Re-enter your password': 'Ilagay muli ang iyong password',
  'Re-enter the new password': 'Ilagay muli ang bagong password',
  'Password (at least 8 characters)': 'Password (hindi bababa sa 8 character)',
  'Password must be at least 8 characters.':
      'Dapat hindi bababa sa 8 character ang password.',
  'Passwords do not match.': 'Hindi magkatugma ang mga password.',
  'This field is required.': 'Kinakailangan ang field na ito.',
  'Select an accredited TODA.': 'Pumili ng akreditadong TODA.',
  'Select a barangay.': 'Pumili ng barangay.',
  'Select an application type.': 'Pumili ng uri ng aplikasyon.',
  'A signature is already on file from your previous submission. Draw again only if you want to replace it.':
      'Mayroon nang pirma sa file mula sa iyong nakaraang pagsusumite. Gumuhit muli lamang kung nais mong palitan ito.',
  'Draw your signature below, or type your full name if drawing is not possible.':
      'Iguhit ang iyong pirma sa ibaba, o i-type ang iyong buong pangalan kung hindi posible ang pagguhit.',
  'Sign here': 'Pumirma rito',
  'Clear signature': 'I-clear ang pirma',
  'Typed signature': 'Naka-type na pirma',
  'The signature image is empty or too large.':
      'Walang laman o masyadong malaki ang larawan ng pirma.',
  'A signature is required.': 'Kinakailangan ang pirma.',
  'Required': 'Kinakailangan',

  // ── Documents ─────────────────────────────────────────────────────────────
  'Document (PDF or image)': 'Dokumento (PDF o larawan)',
  'Documents must be PDF, JPEG or PNG files.':
      'Dapat PDF, JPEG o PNG na file ang mga dokumento.',
  'Choose a PDF, JPEG or PNG file.': 'Pumili ng PDF, JPEG o PNG na file.',
  'Each document must not exceed 10 MB.':
      'Hindi dapat lumampas sa 10 MB ang bawat dokumento.',
  'Upload a clear photo or PDF of each requirement. PDF, JPEG or PNG, up to 10 MB each.':
      'Mag-upload ng malinaw na larawan o PDF ng bawat kinakailangan. PDF, JPEG o PNG, hanggang 10 MB bawat isa.',
  'Upload a corrected copy of any requirement that was rejected.':
      'Mag-upload ng tamang kopya ng anumang kinakailangang tinanggihan.',
  'No file has been recorded for this requirement.':
      'Walang naitalang file para sa kinakailangang ito.',
  'Not on file': 'Wala sa file',
  'Document verified': 'Na-verify ang dokumento',
  'Document rejected': 'Tinanggihan ang dokumento',
  'Document replaced. It will be reviewed again.':
      'Napalitan ang dokumento. Susuriin itong muli.',
  'Uploaded ': 'Na-upload ',
  'The OR/CR must be a PDF, JPEG or PNG file.':
      'Dapat PDF, JPEG o PNG na file ang OR/CR.',
  'The OR/CR must not exceed 10 MB.':
      'Hindi dapat lumampas sa 10 MB ang OR/CR.',
  'Upload the front and back of the OR/CR as ONE PDF or photo. It will be reused automatically when you submit the application.':
      'I-upload ang harap at likod ng OR/CR bilang ISANG PDF o larawan. Awtomatiko itong gagamitin muli kapag isinumite mo ang aplikasyon.',
  'The OR/CR from your approved request is already attached (':
      'Nakakabit na ang OR/CR mula sa iyong naaprubahang kahilingan (',
  'Member Association Certificate': 'Sertipiko ng Kasapi sa Asosasyon',
  'Certificate of Registration (CR) number':
      'Numero ng Certificate of Registration (CR)',
  'Could not load this document right now. Please try again.':
      'Hindi ma-load ang dokumentong ito ngayon. Subukan muli.',
  'Could not open this document right now. Please try again.':
      'Hindi mabuksan ang dokumentong ito ngayon. Subukan muli.',
  'PDF preview is not available in the app yet. The file is stored securely and staff can open it.':
      'Wala pang PDF preview sa app. Ligtas na nakaimbak ang file at mabubuksan ito ng staff.',
  'The preview could not be loaded. It may have expired - reopen to refresh.':
      'Hindi ma-load ang preview. Maaaring nag-expire na ito - buksan muli upang i-refresh.',

  // ── Certificate / QR ─────────────────────────────────────────────────────
  'Certificate holder': 'May-ari ng sertipiko',
  'Verify a certificate': 'I-verify ang sertipiko',
  'Verify code': 'I-verify ang code',
  'Verification code': 'Code ng verification',
  'Scan again': 'I-scan muli',
  'Scan another': 'Mag-scan ng iba',
  'Certificate not found': 'Hindi natagpuan ang sertipiko',
  'The certificate file is not available yet.':
      'Wala pang available na file ng sertipiko.',
  'The certificate file is not available yet. It appears here once the municipal office attaches it.':
      'Wala pang available na file ng sertipiko. Lalabas ito dito kapag naisama na ito ng munisipal na tanggapan.',
  'Point the camera at the certificate\'s QR code.':
      'Itutok ang camera sa QR code ng sertipiko.',
  'Or type the code printed under the QR':
      'O i-type ang code na nakalimbag sa ilalim ng QR',
  'The holder\'s name is shown masked. The verification code identifies a franchise only and contains no personal data.':
      'Nakatago ang pangalan ng may-ari. Ang verification code ay tumutukoy lamang sa prangkisa at walang personal na datos.',
  'No franchise matches this code. Check the characters and try again - the code is not case-sensitive, and spaces or dashes are ignored.':
      'Walang prangkisang tumutugma sa code na ito. Suriin ang mga character at subukan muli - hindi case-sensitive ang code, at binabalewala ang mga espasyo o gitling.',
  'Scanning happens on the municipal server. No personal data is stored on this device.':
      'Nagaganap ang pag-scan sa munisipal na server. Walang personal na datos na nakaimbak sa device na ito.',
  'The camera could not be started.': 'Hindi masimulan ang camera.',
  'e.g. ABCD 2345 EFGH': 'hal. ABCD 2345 EFGH',
  'Copy verification link': 'Kopyahin ang verification link',

  // ── Notifications and announcements ───────────────────────────────────────
  'No notifications yet': 'Wala pang abiso',
  'No announcements yet': 'Wala pang anunsyo',
  'Mark all as read': 'Markahan lahat bilang nabasa',
  'Clear read notifications': 'I-clear ang mga nabasang abiso',
  'Clear read notifications?': 'I-clear ang mga nabasang abiso?',
  'Delete Notification': 'Burahin ang Abiso',
  'Are you sure you want to delete this notification?':
      'Sigurado ka bang gusto mong burahin ang abisong ito?',
  'Every notification you have already read will be removed. Unread ones are kept. This cannot be undone.':
      'Tatanggalin ang lahat ng abisong nabasa mo na. Mananatili ang mga hindi pa nababasa. Hindi na ito maibabalik.',
  'All notifications marked as read.':
      'Namarkahan na ang lahat ng abiso bilang nabasa.',
  'Long-press a notification to delete it.':
      'Pindutin nang matagal ang abiso upang burahin ito.',
  'Applications, decisions, document remarks, renewal reminders and account changes appear here.':
      'Lalabas dito ang mga aplikasyon, desisyon, puna sa dokumento, paalala sa pag-renew at pagbabago sa account.',
  'Notices from the franchising office - renewal windows, assemblies and office advisories - appear here.':
      'Lalabas dito ang mga abiso mula sa tanggapan ng prangkisa - mga panahon ng pag-renew, asembleya at advisory ng tanggapan.',
  'Announcements published by the Sangguniang Bayan office.':
      'Mga anunsyong inilathala ng tanggapan ng Sangguniang Bayan.',
  'Office announcement': 'Anunsyo ng tanggapan',
  'Posted by ': 'Inilathala ni ',
  'Agreement': 'Kasunduan',
  'User Agreement': 'Kasunduan ng Gumagamit',

  // ── Appointments ──────────────────────────────────────────────────────────
  'No upcoming appointments': 'Walang nalalapit na appointment',
  'No past appointments': 'Walang nakaraang appointment',
  'Completed, missed and cancelled appointments appear here once the municipal office closes them out.':
      'Lalabas dito ang mga kumpleto, hindi nasipotan at kinanselang appointment kapag isinara na sila ng munisipal na tanggapan.',
  'Today': 'Ngayon',
  'Tomorrow': 'Bukas',
  'Yesterday': 'Kahapon',
  'Evaluation': 'Ebalwasyon',
  'Physical document submission': 'Paghahain ng pisikal na dokumento',
  'Hearing': 'Pagdinig',
  'Document release': 'Paglabas ng dokumento',
  'Other': 'Iba pa',
  'Venue': 'Lugar',
  'Notes': 'Tala',
  'Scheduled on': 'Nakatakda noong',

  // ── Settings ──────────────────────────────────────────────────────────────
  'Preferences': 'Mga Kagustuhan',
  'Current language': 'Kasalukuyang wika',
  'Tap to use this language': 'I-tap para gamitin ang wikang ito',
  'Only languages the application can fully display are listed.':
      'Ang mga wikang ganap na maipapakita ng aplikasyon lamang ang nakalista.',
  'Accepted': 'Tinanggap',
  'Acceptance required': 'Kinakailangan ang pagtanggap',
  'Read the complete agreement': 'Basahin ang kumpletong kasunduan',
  'About': 'Tungkol sa App',
  'Application version': 'Bersyon ng aplikasyon',
  'Check for updates': 'Suriin ang mga update',
  'See whether a newer build is available':
      'Tingnan kung may mas bagong build na available',
  'Web address': 'Web address',
  'You are on the latest version': 'Nasa pinakabagong bersyon ka',
  'Could not check for updates. Check your connection and try again.':
      'Hindi ma-check ang mga update. Suriin ang iyong koneksyon at subukan muli.',
  'Could not check for updates.': 'Hindi ma-check ang mga update.',
  'Update available': 'Available ang update',
  'Open install page': 'Buksan ang pahina ng pag-install',
  'Could not open the download page. Visit sbtf-application.vercel.app/install on your browser.':
      'Hindi mabuksan ang pahina ng download. Bisitahin ang sbtf-application.vercel.app/install sa iyong browser.',
  'Log Out?': 'Mag-logout?',
  'Are you sure you want to log out?':
      'Sigurado ka bang gusto mong mag-logout?',
  'Cancel request?': 'Kanselahin ang kahilingan?',
  'Cancel request': 'Kanselahin ang kahilingan',

  // ── Auth copy ─────────────────────────────────────────────────────────────
  'Don\'t have an account?': 'Wala pang account?',
  'Enter the e-mail address on your driver or operator account. We will send a 6-digit code to reset your password.':
      'Ilagay ang e-mail address ng iyong driver o operator account. Magpapadala kami ng 6 na digit na code upang i-reset ang iyong password.',
  'Choose a new password for your account. Use at least 8 characters.':
      'Pumili ng bagong password para sa iyong account. Gumamit ng hindi bababa sa 8 character.',
  'Confirm your e-mail': 'Kumpirmahin ang iyong e-mail',
  'Register as a tricycle driver or operator. Your role is assigned automatically on the server - it cannot be chosen here.':
      'Magrehistro bilang driver o operator ng traysikel. Awtomatikong itinatakda ng server ang iyong role - hindi ito mapipili rito.',
  '6-digit code': '6 na digit na code',
  'A new 6-digit code is on its way. Check your inbox and ':
      'Papadating na ang bagong 6 na digit na code. Tingnan ang iyong inbox at ',

  // ── Onboarding ────────────────────────────────────────────────────────────
  'Get started': 'Magsimula',
  'Choose your language': 'Piliin ang iyong wika',
  'Review agreement': 'Suriin ang kasunduan',
  'Accept and continue': 'Tanggapin at magpatuloy',
  'Step 1 of 3 - Language': 'Hakbang 1 ng 3 - Wika',
  'Step 3 of 3 - Terms': 'Hakbang 3 ng 3 - Mga Tuntunin',
  'Selected': 'Napili',
  'Tap to select': 'I-tap para piliin',
  'Your franchise and driver registration, in one place':
      'Ang iyong prangkisa at pagpaparehistro ng driver, sa isang lugar',
  'The next screens take less than a minute.':
      'Aabutin ng wala pang isang minuto ang mga susunod na screen.',
  'Franchise applications': 'Mga aplikasyon sa prangkisa',
  'Status tracking': 'Pagsubaybay sa status',
  'Documents & certificates': 'Mga dokumento at sertipiko',
  'Updates': 'Mga update',
  'Follow every step of your case':
      'Subaybayan ang bawat hakbang ng iyong kaso',
  'Keep your records within reach': 'Itago ang iyong mga rekord sa kamay',
  'Stay informed by the office': 'Manatiling may alam mula sa tanggapan',
  'Start from your phone and complete the same process the office uses.':
      'Magsimula sa iyong telepono at tapusin ang parehong prosesong ginagamit ng tanggapan.',
  'See where your application is and what the office needs from you.':
      'Tingnan kung nasaan na ang iyong aplikasyon at kung ano ang kailangan ng tanggapan mula sa iyo.',
  'Manage requirements and present your franchise certificate anytime.':
      'Pamahalaan ang mga kinakailangan at ipakita ang iyong sertipiko ng prangkisa anumang oras.',
  'Notices and decisions arrive in the app, so you do not miss a step.':
      'Dumarating sa app ang mga abiso at desisyon, kaya hindi ka makakaligtaan ng hakbang.',
  'Request an application form, then complete it once the office issues it.':
      'Humiling ng request form, pagkatapos ay kumpletuhin ito kapag inilabas na ng tanggapan.',
  'Enter operator, vehicle, TODA and barangay details in a guided wizard.':
      'Ilagay ang detalye ng operator, sasakyan, TODA at barangay sa gabay na wizard.',
  'Upload the four required documents directly from your device.':
      'I-upload ang apat na kinakailangang dokumento mula sa iyong device.',
  'Live application status and staff remarks on each document.':
      'Live na status ng aplikasyon at puna ng staff sa bawat dokumento.',
  'A timeline of submissions, reviews and decisions.':
      'Timeline ng mga pagsusumite, pagsusuri at desisyon.',
  'Appointments and hearings booked by the franchising office.':
      'Mga appointment at pagdinig na inayos ng tanggapan ng prangkisa.',
  'Replace a rejected document while the application is under review.':
      'Palitan ang tinanggihang dokumento habang sinusuri ang aplikasyon.',
  'Open your franchise certificate and its QR code.':
      'Buksan ang iyong sertipiko ng prangkisa at ang QR code nito.',
  'Scan a certificate QR to verify it against the official record.':
      'I-scan ang QR ng sertipiko upang i-verify ito sa opisyal na rekord.',
  'A notification feed with an unread count.':
      'Feed ng abiso na may bilang ng hindi pa nababasa.',
  'Updates appear in real time while the app is open.':
      'Lumalabas ang mga update nang real time habang bukas ang app.',
  'You\'re all set': 'Handa ka na',
  'Next, sign in or create your driver account.':
      'Susunod, mag-sign in o gumawa ng iyong driver account.',
  'Accepted on': 'Tinanggap noong',
  'Version ': 'Bersyon ',
  'effective ': 'epektibo ',
  'English is the only language fully available in this release. The application will not offer a language it cannot display.':
      'Ang English at Filipino ang mga wikang ganap na available sa release na ito.',
  'The User Agreement has been updated. Please review and accept this revision to continue.':
      'Na-update ang Kasunduan ng Gumagamit. Suriin at tanggapin ang rebisyong ito upang magpatuloy.',
  'I have read and understood the User Agreement, and I accept its terms for using the MTOP System.':
      'Nabasa at naunawaan ko ang Kasunduan ng Gumagamit, at tinatanggap ko ang mga tuntunin nito para sa paggamit ng MTOP System.',
  'You must accept the agreement before you can continue.':
      'Dapat mong tanggapin ang kasunduan bago ka magpatuloy.',
  'Acceptance of this agreement is recorded with its version and the time you accepted it. For a signed-in account it is also stored with your profile as an audit record.':
      'Ang pagtanggap sa kasunduang ito ay naitala kasama ang bersyon nito at ang oras na tinanggap mo ito. Para sa naka-sign in na account, nakaimbak din ito sa iyong profile bilang audit record.',

  // ── Agreement section titles and summaries ────────────────────────────────
  'Authorized access': 'Awtorisadong access',
  'Accurate information': 'Tumpak na impormasyon',
  'Proper use of the system': 'Wastong paggamit ng sistema',
  'Confidentiality and data privacy': 'Pagiging kompidensyal at privacy ng datos',
  'Prohibited activities': 'Mga ipinagbabawal na gawain',
  'Agreement updates': 'Mga update sa kasunduan',
  'Use only your own account and only for legitimate franchise and driver registration transactions.':
      'Gamitin lamang ang sarili mong account at para lamang sa lehitimong transaksyon sa prangkisa at pagpaparehistro ng driver.',
  'You are responsible for the truth, completeness and legality of every detail and document you submit.':
      'Ikaw ang may pananagutan sa katotohanan, pagkakumpleto at legalidad ng bawat detalyeng at dokumentong isinusumite mo.',
  'Use the features as intended and do not interfere with the service or other users.':
      'Gamitin ang mga feature ayon sa layunin at huwag makagambala sa serbisyo o sa ibang gumagamit.',
  'Personal data is processed under the Data Privacy Act and only for official franchising purposes.':
      'Pinoproseso ang personal na datos sa ilalim ng Data Privacy Act at para lamang sa opisyal na layunin ng prangkisa.',
  'Impersonation, forged documents, malware, harassment and unauthorized access are grounds for account action.':
      'Ang pagpapanggap, pekeng dokumento, malware, panliligalig at hindi awtorisadong access ay mga dahilan para sa aksyon sa account.',
  'Accepting this revision is required before you can use the system; a new revision must be accepted when published.':
      'Kinakailangan ang pagtanggap sa rebisyong ito bago mo gamitin ang sistema; dapat tanggapin ang bagong rebisyon kapag nailathala na.',

  // ── Generic errors ────────────────────────────────────────────────────────
  'Could not load the TODA list.': 'Hindi ma-load ang listahan ng TODA.',
  'Could not load the barangay list.':
      'Hindi ma-load ang listahan ng barangay.',
  'Could not load your franchises.': 'Hindi ma-load ang iyong mga prangkisa.',
  'Could not reach the municipal service. Check your connection and try again.':
      'Hindi maabot ang munisipal na serbisyo. Suriin ang koneksyon at subukan muli.',
  'The database is not ready. It does not match the schema this app expects.':
      'Hindi pa handa ang database. Hindi ito tumutugma sa schema na inaasahan ng app.',
  'Preview mode is on, so this action is disabled. Connect a Supabase project to use it.':
      'Naka-on ang preview mode, kaya hindi pinagana ang aksyong ito. Ikonekta ang isang Supabase project upang magamit ito.',
  'Preview mode - Supabase is not connected, so sign-in is shown but disabled. The app runs without a database.':
      'Preview mode - hindi konektado ang Supabase, kaya ipinapakita ang sign-in ngunit hindi pinagana. Tumatakbo ang app nang walang database.',
  'Copy run command': 'Kopyahin ang run command',
  'Run command copied': 'Nakopya ang run command',
  'This build has no Supabase project URL or publishable key, so it cannot connect to the database. Pass both values at build time with --dart-define. Only publishable values are needed; the anon key is safe to ship because Row Level Security enforces access.':
      'Walang Supabase project URL o publishable key ang build na ito, kaya hindi ito makakonekta sa database. Ipasa ang dalawang value sa oras ng build gamit ang --dart-define. Mga publishable value lamang ang kailangan; ligtas i-ship ang anon key dahil ipinapatupad ng Row Level Security ang access.',
  'Welcome to MTOP': 'Maligayang pagdating sa MTOP',

  // ── Validation messages ───────────────────────────────────────────────────
  'Enter the vehicle year.': 'Ilagay ang taon ng sasakyan.',
  'Year must be between 1950 and': 'Dapat nasa pagitan ng 1950 at',
  'Enter the seating capacity.': 'Ilagay ang kapasidad ng upuan.',
  'Capacity must be between 1 and 12.':
      'Dapat nasa pagitan ng 1 at 12 ang kapasidad.',
  'Must not exceed': 'Hindi dapat lumampas sa',
  'must not exceed': 'ay hindi dapat lumampas sa',
  'characters.': 'character.',
  'is required.': 'ay kinakailangan.',
  'Enter the 6-digit code from the e-mail.':
      'Ilagay ang 6 na digit na code mula sa e-mail.',
  'First name is required.': 'Kinakailangan ang pangalan.',
  'Last name is required.': 'Kinakailangan ang apelyido.',
  'Contact number is required.': 'Kinakailangan ang numero ng kontak.',
  'No franchises available to renew.':
      'Walang prangkisang available na i-renew.',
  'Announcement': 'Anunsyo',
  'official seal': 'opisyal na selyo',
  'Request form': 'Form ng Kahilingan',
  'Year': 'Taon',
  'Step': 'Hakbang',
  'of': 'ng',
  'In': 'Sa',
  'days': 'araw',
  'day': 'araw',
  'ago': 'ang nakalipas',
  'WELCOME TO': 'MALIGAYANG PAGDATING SA',
  'Issued on': 'Inisyu noong',
  'Issued': 'Inisyu',
  'Expires': 'Mag-eexpire',
  'Effective': 'Epektibo',
  'is ready': 'ay handa na',
  'You can still verify a certificate by typing its code below.':
      'Maaari mo pa ring i-verify ang sertipiko sa pamamagitan ng pag-type ng code nito sa ibaba.',
  'You will need to file a new request form before applying again.':
      'Kailangan mong maghain ng bagong request form bago muling mag-apply.',
  'Your application was received.':
      'Natanggap na ang iyong aplikasyon.',
  'Your request': 'Ang iyong kahilingan',
  'is with the franchising office.':
      'ay nasa tanggapan ng prangkisa.',
  'You can start the application once it is approved.':
      'Maaari mong simulan ang aplikasyon kapag naaprubahan na ito.',

  // ── Remaining screen copy ─────────────────────────────────────────────────
  'Cannot submit yet': 'Hindi pa maisusumite',
  'Please complete the highlighted fields.':
      'Kumpletuhin ang mga naka-highlight na field.',
  'None on file': 'Wala sa file',
  'No entries yet': 'Wala pang entry',
  'Review & submit': 'Suriin at isumite',
  'Check each detail and change anything that has been updated.':
      'Suriin ang bawat detalye at baguhin ang anumang na-update.',
  'Could not submit the application. Check your connection and try again.':
      'Hindi maisumite ang aplikasyon. Suriin ang koneksyon at subukan muli.',
  'Select your barangay': 'Piliin ang iyong barangay',
  'You have no franchise available to renew.':
      'Wala kang prangkisang available na i-renew.',
  'No franchise available to renew':
      'Walang prangkisang available na i-renew',
  'Purok / street, barangay': 'Purok / kalye, barangay',
  'Documentary requirements': 'Mga kinakailangang dokumento',
  'Applied Route': 'Rutang inaplayan',
  'No. of Units Applied For': 'Bilang ng yunit na inaplayan',
  'Motor No.': 'Blg. ng Motor',
  'Chassis No.': 'Blg. ng Tsasis',
  'Plate No.': 'Blg. ng Plaka',
  'Registered Owner': 'Rehistradong May-ari',
  'CTC No.': 'Blg. ng CTC',
  'Single Proprietorship': 'Nag-iisang Pagmamay-ari',
  'PDF, JPEG or PNG, up to 10 MB': 'PDF, JPEG o PNG, hanggang 10 MB',
  'PDF, JPEG or PNG \u00b7 up to 10 MB': 'PDF, JPEG o PNG - hanggang 10 MB',
  'Choose file': 'Pumili ng file',
  'My applications': 'Aking mga aplikasyon',
  'Check the vehicle details and CTC, then change anything that has been updated.':
      'Suriin ang detalye ng sasakyan at CTC, pagkatapos ay baguhin ang anumang na-update.',
  'Upload the combined OR/CR file.': 'I-upload ang pinagsamang OR/CR file.',
  'Request resubmitted to staff.': 'Isinumite muli ang kahilingan sa staff.',
  'Request submitted. Staff will review it.':
      'Naisumite ang kahilingan. Susuriin ito ng staff.',
  'Could not submit the request. Check your connection and try again.':
      'Hindi maisumite ang kahilingan. Suriin ang koneksyon at subukan muli.',
  'Edit request form': 'I-edit ang request form',
  'Request': 'Kahilingan',
  'Signature': 'Pirma',
  'Your full name': 'Iyong buong pangalan',
  'Resubmit request': 'Isumite muli ang kahilingan',
  'Upload combined OR/CR': 'I-upload ang pinagsamang OR/CR',
  'Tap to replace': 'I-tap para palitan',
  'Please review the details and resubmit.':
      'Suriin ang mga detalye at isumite muli.',
  'Outcome': 'Resulta',
  'Note from the office': 'Tala mula sa tanggapan',
  'Your application': 'Ang iyong aplikasyon',
  'Date and time': 'Petsa at oras',
  'To be announced': 'Ipapaalam pa',
  'Booked on': 'Naka-book noong',
  'This appointment belongs to one of your applications.':
      'Ang appointment na ito ay kabilang sa isa sa iyong mga aplikasyon.',
  'Service unavailable': 'Hindi available ang serbisyo',
  'Could not load your profile': 'Hindi ma-load ang iyong profile',
  'The e-mail address or password is incorrect.':
      'Mali ang e-mail address o password.',
  'That code is incorrect or has expired. Request a new code and try again.':
      'Mali o nag-expire na ang code. Humiling ng bagong code at subukan muli.',
  'Too many code requests. Wait a minute, then try again.':
      'Masyadong maraming kahilingan ng code. Maghintay ng isang minuto at subukan muli.',
  'Choose a stronger password - at least 8 characters.':
      'Pumili ng mas matibay na password - hindi bababa sa 8 character.',
  'The new password must be different from your current password.':
      'Dapat iba ang bagong password sa iyong kasalukuyang password.',
  'No internet connection. Please check your network and try again.':
      'Walang koneksyon sa internet. Suriin ang iyong network at subukan muli.',
  'Sign in with your driver or operator account to continue.':
      'Mag-sign in gamit ang iyong driver o operator account upang magpatuloy.',
  'Your e-mail address has not been confirmed yet. ':
      'Hindi pa nakumpirma ang iyong e-mail address. ',
  'No code has been sent yet. Tap "Send a new code" below.':
      'Wala pang naipadalang code. I-tap ang "Magpadala ng bagong code" sa ibaba.',
  'Enter your code': 'Ilagay ang iyong code',
  'Verify and sign in': 'I-verify at mag-sign in',
  'Send a new code': 'Magpadala ng bagong code',
  'Use a different e-mail': 'Gumamit ng ibang e-mail',
  'Show password': 'Ipakita ang password',
  'Hide password': 'Itago ang password',
  'Could not sign in. Check your connection and try again.':
      'Hindi makapag-sign in. Suriin ang koneksyon at subukan muli.',
  'Could not send the code. Check your connection and try again.':
      'Hindi maipadala ang code. Suriin ang koneksyon at subukan muli.',
  'Could not save the new password. Check your connection and try again.':
      'Hindi ma-save ang bagong password. Suriin ang koneksyon at subukan muli.',
  'The account could not be created and no code was sent. Check your connection and try again.':
      'Hindi magawa ang account at walang naipadalang code. Suriin ang koneksyon at subukan muli.',
  'No e-mail address is linked to this request. Return to sign in and start again.':
      'Walang naka-link na e-mail address sa kahilingang ito. Bumalik sa pag-sign in at magsimula muli.',
  'Could not verify the code. Check your connection and try again.':
      'Hindi ma-verify ang code. Suriin ang koneksyon at subukan muli.',
  'This account has been suspended. ': 'Nasuspinde ang account na ito. ',
  'This account is not active. ': 'Hindi aktibo ang account na ito. ',
  'No profile is linked to this account yet. ':
      'Wala pang naka-link na profile sa account na ito. ',
  'Municipal staff and administrators use the web console. This app is for drivers and operators only.':
      'Ginagamit ng staff at administrador ng munisipyo ang web console. Para lamang sa mga driver at operator ang app na ito.',
  'Verification QR': 'Verification QR',
  'This franchise has been archived': 'Na-archive ang prangkisang ito',
  'You can still file a renewal.': 'Maaari ka pa ring maghain ng pag-renew.',
  'Verification link copied.': 'Nakopya ang verification link.',
  'Could not prepare the certificate for download. Please try again.':
      'Hindi maihanda ang sertipiko para sa download. Subukan muli.',
  'No app is available to open the certificate. The link has been copied instead.':
      'Walang app na available upang buksan ang sertipiko. Nakopya na lang ang link.',
  'Could not replace the document. Check your connection and try again.':
      'Hindi mapalitan ang dokumento. Suriin ang koneksyon at subukan muli.',
  'Your applications and documents stay on the server.':
      'Nananatili sa server ang iyong mga aplikasyon at dokumento.',
  'Not active': 'Hindi aktibo',
  'That announcement is no longer available.':
      'Hindi na available ang anunsyong iyon.',
  'That form request is no longer available.':
      'Hindi na available ang request form na iyon.',
  'That certificate is no longer available.':
      'Hindi na available ang sertipikong iyon.',
  'That appointment is no longer available.':
      'Hindi na available ang appointment na iyon.',
  'Notification deleted.': 'Nabura ang abiso.',
  'Read notifications cleared.': 'Na-clear ang mga nabasang abiso.',
  'Everything has been read.': 'Nabasa na lahat.',
  'Where to find the values: ': 'Saan makikita ang mga value: ',
  'The municipal office must apply the database migrations.':
      'Dapat ilapat ng munisipal na tanggapan ang mga database migration.',
  'Turn on Wi-Fi or mobile data, then try again.':
      'I-on ang Wi-Fi o mobile data, pagkatapos ay subukan muli.',
  'Try again. If it keeps happening, contact the municipal office.':
      'Subukan muli. Kung patuloy pa rin ito, makipag-ugnayan sa munisipal na tanggapan.',
  'Pick the language used across the application. You can change this later in Settings.':
      'Piliin ang wikang gagamitin sa buong aplikasyon. Maaari mo itong baguhin mamaya sa Mga Setting.',
  'Your preferences are saved on this device. You can review the agreement or change your language later in Settings.':
      'Naka-save ang iyong mga kagustuhan sa device na ito. Maaari mong suriin ang kasunduan o baguhin ang iyong wika mamaya sa Mga Setting.',
  'Scan to open the public verification page. The code identifies this franchise only - it contains no personal information.':
      'I-scan upang buksan ang pampublikong verification page. Ang code ay tumutukoy lamang sa prangkisang ito - walang personal na impormasyon dito.',

  // ── Month names (formatted dates) ─────────────────────────────────────────
  'January': 'Enero',
  'February': 'Pebrero',
  'March': 'Marso',
  'April': 'Abril',
  'May': 'Mayo',
  'June': 'Hunyo',
  'July': 'Hulyo',
  'August': 'Agosto',
  'September': 'Setyembre',
  'October': 'Oktubre',
  'November': 'Nobyembre',
  'December': 'Disyembre',
  'Jan': 'Ene',
  'Feb': 'Peb',
  'Mar': 'Mar',
  'Apr': 'Abr',
  'Jun': 'Hun',
  'Jul': 'Hul',
  'Aug': 'Ago',
  'Sep': 'Set',
  'Oct': 'Okt',
  'Nov': 'Nob',
  'Dec': 'Dis',
  'AM': 'AM',
  'PM': 'PM',
};

/// Exact English → Filipino sentences for the long-form User Agreement.
///
/// Kept in a separate literal so the short UI map above stays readable. The
/// long paragraphs are matched exactly (whitespace-normalised).
const Map<String, String> filipinoAgreementTranslations = <String, String>{
  'Access to the MTOP System is limited to drivers, operators and authorized Sangguniang Bayan personnel who need it for franchising and tricycle driver registration.':
      'Ang access sa MTOP System ay limitado sa mga driver, operator at awtorisadong tauhan ng Sangguniang Bayan na nangangailangan nito para sa prangkisa at pagpaparehistro ng driver ng traysikel.',
  'Your account credentials are personal. Do not share your password, one-time code or signed-in device with another person, and do not use an account that does not belong to you.':
      'Personal ang mga kredensyal ng iyong account. Huwag ibahagi ang iyong password, one-time code o naka-sign in na device sa ibang tao, at huwag gamitin ang account na hindi sa iyo.',
  'Report any unauthorized access, lost device or suspicious activity to the Sangguniang Bayan office immediately so the account can be secured.':
      'Agad na iulat sa tanggapan ng Sangguniang Bayan ang anumang hindi awtorisadong access, nawalang device o kahina-hinalang aktibidad upang ma-secure ang account.',
  'All information you enter - names, contact details, vehicle and plate numbers, TODA and barangay information - must be true, current and complete.':
      'Ang lahat ng impormasyong inilalagay mo - mga pangalan, detalye ng kontak, numero ng sasakyan at plaka, impormasyon ng TODA at barangay - ay dapat totoo, napapanahon at kumpleto.',
  'Documents you upload must be authentic, readable and lawfully obtained. Uploading a falsified, altered or borrowed document is prohibited.':
      'Ang mga dokumentong ina-upload mo ay dapat tunay, nababasa at legal na nakuha. Ipinagbabawal ang pag-upload ng peke, binago o hinihiram na dokumento.',
  'Submitting false information may result in rejection of the application, suspension or deactivation of your account, and may expose you to liability under applicable laws and municipal ordinances.':
      'Ang pagsusumite ng maling impormasyon ay maaaring magresulta sa pagtanggi ng aplikasyon, pagsuspinde o pag-deactivate ng iyong account, at maaaring maglagay sa iyo sa pananagutan sa ilalim ng mga naaangkop na batas at ordinansa ng munisipyo.',
  'Use the application, document, certificate, announcement and notification features only for their intended purpose.':
      'Gamitin ang mga feature ng aplikasyon, dokumento, sertipiko, anunsyo at abiso para lamang sa kanilang nilalayong layunin.',
  'Do not attempt to bypass security controls, access another person\'s records, disrupt the service, or use automated tools to scrape or overload the system.':
      'Huwag subukang lampasan ang mga kontrol sa seguridad, i-access ang rekord ng ibang tao, gambalain ang serbisyo, o gumamit ng automated na tool upang mag-scrape o mag-overload ng sistema.',
  'The system supports the franchising process; it does not guarantee approval of an application. Decisions remain with the authorized office and are made under existing rules and ordinances.':
      'Sinusuportahan ng sistema ang proseso ng prangkisa; hindi nito ginagarantiyahan ang pag-apruba ng aplikasyon. Ang mga desisyon ay nananatili sa awtorisadong tanggapan at ginagawa sa ilalim ng umiiral na mga patakaran at ordinansa.',
  'The system collects and processes personal information and sensitive personal information - including identity details, contact information and documentary requirements - for franchise and driver registration, verification, notifications and related official purposes.':
      'Kinokolekta at pinoproseso ng sistema ang personal na impormasyon at sensitibong personal na impormasyon - kabilang ang detalye ng pagkakakilanlan, impormasyon ng kontak at mga dokumentong kinakailangan - para sa prangkisa at pagpaparehistro ng driver, verification, abiso at kaugnay na opisyal na layunin.',
  'Access is limited by role and by row-level security. Only you and authorized Sangguniang Bayan personnel can read your records; uploaded files are served through short-lived signed links.':
      'Ang access ay limitado ayon sa role at row-level security. Ikaw lamang at ang awtorisadong tauhan ng Sangguniang Bayan ang makakabasa ng iyong mga rekord; ang mga na-upload na file ay ibinibigay sa pamamagitan ng panandaliang signed links.',
  'Your data is retained only as long as necessary for the official purpose and applicable records-retention rules. You may ask the Sangguniang Bayan office about your rights under the Data Privacy Act, including access, correction and other rights provided by law.':
      'Ang iyong datos ay itinatago lamang hangga\'t kinakailangan para sa opisyal na layunin at naaangkop na mga patakaran sa pag-iingat ng rekord. Maaari mong tanungin ang tanggapan ng Sangguniang Bayan tungkol sa iyong mga karapatan sa ilalim ng Data Privacy Act, kabilang ang access, pagwawasto at iba pang karapatang ibinigay ng batas.',
  'The following are prohibited: impersonating another person, creating accounts with false identities, forging or tampering with documents, uploading malware, and using the system to harass or defraud another person.':
      'Ipinagbabawal ang mga sumusunod: pagpapanggap bilang ibang tao, paggawa ng account gamit ang pekeng pagkakakilanlan, pamemeke o pagbabago ng dokumento, pag-upload ng malware, at paggamit ng sistema upang manglupig o mandaya ng ibang tao.',
  'Attempting to access, modify or delete records you are not authorized to access is prohibited, whether through the interface or by direct technical means.':
      'Ipinagbabawal ang pagtatangkang i-access, baguhin o burahin ang mga rekord na hindi ka awtorisadong i-access, sa pamamagitan man ng interface o ng direktang teknikal na paraan.',
  'Violations may lead to suspension or deactivation of the account and may be referred to the appropriate authorities.':
      'Ang mga paglabag ay maaaring humantong sa pagsuspinde o pag-deactivate ng account at maaaring i-refer sa mga naaangkop na awtoridad.',
  'This is version ':
      'Ito ang bersyon ',
  ' of the User Agreement, effective ':
      ' ng Kasunduan ng Gumagamit, epektibo ',
  'The Sangguniang Bayan office may update this agreement when the system or applicable rules change. A new revision must be accepted before you continue using the system.':
      'Maaaring i-update ng tanggapan ng Sangguniang Bayan ang kasunduang ito kapag nagbago ang sistema o ang mga naaangkop na patakaran. Dapat tanggapin ang bagong rebisyon bago ka magpatuloy sa paggamit ng sistema.',
  'Your acceptance - the agreement version and the time you accepted it - is recorded on this device and, for a signed-in account, also stored with your profile so the office has an audit record.':
      'Ang iyong pagtanggap - ang bersyon ng kasunduan at ang oras na tinanggap mo ito - ay naitala sa device na ito at, para sa naka-sign in na account, nakaimbak din sa iyong profile upang may audit record ang tanggapan.',
  'I hereby certify that the above information are true and correct and that I am applying for a franchise to operate the above-described tricycle for public service.':
      'Pinatutunayan ko sa pamamagitan nito na ang impormasyon sa itaas ay totoo at tama at ako ay nag-a-apply ng prangkisa upang patakbuhin ang inilarawang traysikel para sa pampublikong serbisyo.',
  'By submitting, you confirm the information and documents are true and correct. The municipal office will review them and notify you of any change in status.':
      'Sa pagsusumite, kinukumpirma mo na ang impormasyon at mga dokumento ay totoo at tama. Susuriin ito ng munisipal na tanggapan at aabisuhan ka sa anumang pagbabago sa status.',
  'Review the official application form below before submitting. Your CTC and signature from the approved request are used automatically.':
      'Suriin ang opisyal na application form sa ibaba bago isumite. Awtomatikong gagamitin ang iyong CTC at pirma mula sa naaprubahang kahilingan.',
  'MOTORCYCLE / TRICYCLE PARTICULARS': 'DETALYE NG MOTORSIKLO / TRAYSIKEL',
  'APPLICATION FOR FRANCHISE TRICYCLE SERVICE':
      'APLIKASYON PARA SA PRANGKISA NG TRAYSIKEL',
  'Republic of the Philippines': 'Republika ng Pilipinas',
  'Province of Batangas': 'Lalawigan ng Batangas',
  'Municipality of Mabini': 'Munisipalidad ng Mabini',
  'OFFICE OF THE SANGGUNIANG BAYAN': 'TANGGAPAN NG SANGGUNIANG BAYAN',
  'Mabini, Batangas': 'Mabini, Batangas',
  'Driver / Operator': 'Driver / Operator',
  'Applied route': 'Rutang inaplayan',
  'Applied route / service area': 'Rutang inaplayan / lugar ng serbisyo',
  'Application No.: ': 'Aplikasyon Blg.: ',
  'Franchise': 'Prangkisa',
};

/// Longest-phrase replacement used for interpolated strings.
final RegExp _phrasePattern = _buildPhrasePattern();

RegExp _buildPhrasePattern() {
  final keys = <String>{
    ...filipinoTranslations.keys,
    ...filipinoAgreementTranslations.keys,
  }
      .map((key) => key.trim())
      .where((key) => key.length > 1 && !key.contains(r'$'))
      .toSet()
      .toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final alternation = keys.map(RegExp.escape).join('|');
  return RegExp('(?<![A-Za-z0-9])(?:$alternation)(?![A-Za-z0-9])');
}

/// Translates [source] into Filipino.
///
/// Exact matches win so full sentences read naturally; otherwise the fixed
/// phrases inside an interpolated string are replaced in place, which keeps
/// values such as names, dates and reference numbers untouched.
String translateToFilipino(String source) {
  if (source.isEmpty) return source;
  final normalised = _normalize(source);
  final exact = filipinoTranslations[normalised] ??
      filipinoAgreementTranslations[normalised];
  if (exact != null) return exact;
  if (!_phrasePattern.hasMatch(normalised)) return source;
  return normalised.replaceAllMapped(
    _phrasePattern,
    (match) {
      final key = match[0]!.trim();
      return filipinoTranslations[key] ??
          filipinoAgreementTranslations[key] ??
          match[0]!;
    },
  );
}

/// The maximum number of words a single phrase rule may span.
int get maxFilipinoPhraseWords => 18;

