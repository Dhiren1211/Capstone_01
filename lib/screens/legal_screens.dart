import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A reusable full-text legal/info screen with title, body, and scrolling.
class InfoTextScreen extends StatelessWidget {
  const InfoTextScreen({
    super.key,
    required this.title,
    required this.lastUpdated,
    required this.sections,
  });

  final String title;
  final String lastUpdated;
  final List<InfoSection> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                Text(
                  'Last updated $lastUpdated',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiaryOf(context),
                  ),
                ),
                const SizedBox(height: 20),
                for (final s in sections) ...[
                  Semantics(
                    header: true,
                    child: Text(
                      s.heading,
                      style: AppTextStyles.h3Bold.copyWith(
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.body,
                    style: AppTextStyles.body.copyWith(
                      height: 1.6,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Divider(color: AppColors.dividerOf(context)),
                const SizedBox(height: 12),
                Text(
                  'smartFind, Kyungsung University',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiaryOf(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InfoSection {
  const InfoSection({required this.heading, required this.body});
  final String heading;
  final String body;
}

/// Terms of Service — full content.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoTextScreen(
      title: 'Terms of Service',
      lastUpdated: 'November 2026',
      sections: [
        InfoSection(
          heading: '1. Acceptance of Terms',
          body: 'By accessing and using the smartFind application ("the Service"), you agree to be bound by these Terms of Service and all applicable laws and regulations. If you do not agree with any of these terms, you are prohibited from using or accessing this Service. The Service is provided to help community members report and recover lost or found items.',
        ),
        InfoSection(
          heading: '2. User Responsibilities',
          body: 'You agree to provide accurate, current, and complete information when creating reports, including item descriptions, locations, and contact details. You are solely responsible for the content you post and for any interactions with other users. You agree not to use the Service for any unlawful purpose, including posting fraudulent or duplicate reports, impersonating other users, or sharing contact information without consent.',
        ),
        InfoSection(
          heading: '3. Item Reports',
          body: 'smartFind is a platform that facilitates reporting and recovery of items. We do not guarantee that any lost item will be found, nor that any found item will be returned. Users are encouraged to verify the identity and ownership of items before completing a handover. The Service is not responsible for the condition, authenticity, or value of any item posted.',
        ),
        InfoSection(
          heading: '4. User Accounts',
          body: 'You are responsible for safeguarding your account credentials and for any activities or actions taken under your account. You agree to notify us immediately of any unauthorized use of your account or any other security breach. We will not be liable for any loss or damage arising from your failure to comply with this section.',
        ),
        InfoSection(
          heading: '5. Privacy',
          body: 'Your use of the Service is also governed by our Privacy Policy, which describes how we collect, use, and share your information. By using the Service, you consent to the data practices described in the Privacy Policy.',
        ),
        InfoSection(
          heading: '6. Limitation of Liability',
          body: 'smartFind, its operators, and Kyungsung University shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including loss of profits, data, or other intangible losses, resulting from your access to or use of, or inability to access or use, the Service.',
        ),
        InfoSection(
          heading: '7. Modifications',
          body: 'We reserve the right to modify or replace these Terms at any time. If a revision is material, we will provide at least 30 days\' notice prior to the new terms taking effect. What constitutes a material change will be determined at our sole discretion.',
        ),
        InfoSection(
          heading: '8. Contact',
          body: 'If you have any questions about these Terms, please contact us at support@smartfind.app or through the contact details in the About screen.',
        ),
      ],
    );
  }
}

/// Privacy Policy — full content.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoTextScreen(
      title: 'Privacy Policy',
      lastUpdated: 'November 2026',
      sections: [
        InfoSection(
          heading: '1. Information We Collect',
          body: 'We collect information you provide directly to us, including your name, email address, and any item reports you submit (item name, description, location, photo, and contact information). We also automatically collect certain information when you use the Service, such as your device identifier, approximate location (with your consent), and usage logs.',
        ),
        InfoSection(
          heading: '2. How We Use Your Information',
          body: 'We use your information to provide, maintain, and improve the Service — to display your reports to other users, to facilitate communication between reporters and finders, to send you notifications about potential matches or new messages, and to monitor and prevent fraud or abuse of the platform.',
        ),
        InfoSection(
          heading: '3. Information Sharing',
          body: 'We do not sell, trade, or otherwise transfer your personal information to third parties without your consent, except for the following cases: (a) when item reports are publicly visible on the feed by design; (b) when you choose to share your contact info with another user via the chat; (c) when required by law or to protect the rights, property, or safety of our users.',
        ),
        InfoSection(
          heading: '4. Data Storage & Security',
          body: 'Your data is stored using Google Firebase services, which use industry-standard security measures. Authentication credentials are hashed and never stored in plain text. Item photos and profile pictures are stored with Cloudinary, an image-hosting provider; anyone who has the web address of a photo can view it, so please do not upload photos that show sensitive information (for example ID cards). Despite these measures, no method of transmission over the internet is 100% secure.',
        ),
        InfoSection(
          heading: '5. Your Rights',
          body: 'You have the right to access, correct, or delete your personal information. You can delete your own reports at any time from the detail page of the report. To delete your entire account and all associated data, contact support@smartfind.app. Once we receive your request, we will delete your information within 30 days.',
        ),
        InfoSection(
          heading: '6. Location Data',
          body: 'With your permission, the Service may collect and use your device\'s location to tag reports with GPS coordinates and to display items on the campus map. You can turn this off at any time in Settings, under Privacy, Location services. Approximate location is used only when the app is in the foreground.',
        ),
        InfoSection(
          heading: '7. Notifications and Third-Party Services',
          body: 'When a report looks like one of yours, or someone messages you, the app shows a notification on your phone. This uses Firebase Cloud Messaging, which receives a device token linked to your account; the token is removed when you log out. If you use the optional matching server, the text and, when both reports have one, the photos of reports that might match can be sent to it and to OpenRouter to rate the similarity. To show the campus map, find an address for your location and calculate walking routes, the app contacts OpenStreetMap services (map tiles, Nominatim and OSRM), which receive the coordinates involved and your IP address. Photos are hosted by Cloudinary, and sign-in and data storage are provided by Google Firebase.',
        ),
        InfoSection(
          heading: '8. Changes to This Policy',
          body: 'We may update this Privacy Policy from time to time. We will notify you of any material changes by posting the new policy in the app and, if necessary, by sending you a notification. Your continued use of the Service after any changes constitutes acceptance of the new Privacy Policy.',
        ),
      ],
    );
  }
}

/// Community Guidelines — full content.
class CommunityGuidelinesScreen extends StatelessWidget {
  const CommunityGuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoTextScreen(
      title: 'Community Guidelines',
      lastUpdated: 'November 2026',
      sections: [
        InfoSection(
          heading: '1. Be Honest',
          body: 'Only report items that you have actually lost or genuinely found. False reports waste other users\' time and erode trust in the community. Provide accurate descriptions — including brand, color, distinguishing features, and any contents — so that owners can verify their items.',
        ),
        InfoSection(
          heading: '2. Be Respectful',
          body: 'Treat other users with kindness and respect in all communications. Harassment, hate speech, threats, or discriminatory language will not be tolerated and may result in permanent account suspension. Remember that the person you\'re talking to is a fellow community member trying to help.',
        ),
        InfoSection(
          heading: '3. Be Safe',
          body: 'When meeting another user to hand over an item, choose a public, well-lit location on campus during daytime hours. Bring a friend if possible. Trust your instincts — if something feels wrong, cancel the meeting and contact campus security. Never share financial information or send money to "claim" a found item.',
        ),
        InfoSection(
          heading: '4. Verify Ownership',
          body: 'If you found an item, ask the claimer to describe specific details only the owner would know (a sticker on the inside, the contents, a unique scratch, etc.). Do not hand over an item to the first person who claims it — taking 30 seconds to verify protects the real owner and the community.',
        ),
        InfoSection(
          heading: '5. No Spam or Duplicates',
          body: 'Do not post the same item multiple times to "bump" it. Duplicate reports will be removed. Do not use the chat feature to send unsolicited messages, promotional content, or chain letters.',
        ),
        InfoSection(
          heading: '6. Report Misuse',
          body: 'If you encounter a fake report, a harassing user, or any other misuse of the platform, please email support@smartfind.app. Include the username, item title, and a brief description of the issue. Our team reviews reports within 48 hours.',
        ),
        InfoSection(
          heading: '7. Reunite & Close',
          body: 'When an item is reunited with its owner, please tap the "Mark as Reunited" button on the item detail screen. This removes it from the active feed, helps other users see what\'s still missing, and gives everyone a small win.',
        ),
      ],
    );
  }
}

/// About smartFind screen — app info.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoTextScreen(
      title: 'About smartFind',
      lastUpdated: 'November 2026',
      sections: [
        InfoSection(
          heading: 'What is smartFind?',
          body: 'smartFind is a community lost-and-found application built specifically for the Kyungsung University campus. It allows students, faculty, and staff to report lost or found items, search the feed, view items on a campus map, and connect with the person who reported an item.',
        ),
        InfoSection(
          heading: 'Our Mission',
          body: 'We believe that no one should lose something important and never see it again. By building a focused, friendly, and fast lost-and-found platform for the Kyungsung community, we hope to reunite thousands of items with their owners every year.',
        ),
        InfoSection(
          heading: 'How It Works',
          body: '1. Tap the central + button to report a lost or found item.\n2. Add a photo, name, category, and the building where you lost/found it.\n3. Browse the home feed or search by name, location, or category.\n4. Open any item to see details and tap the message button to start a chat.\n5. Open the numbered campus map, tap a building and choose View details.\n6. smartFind compares new reports with existing ones and alerts you when they look about 70% alike or more.\n7. Once an item is reunited with its owner, mark it as reunited.',
        ),
        InfoSection(
          heading: 'Built With',
          body: 'Flutter for the app, Firebase for sign-in, Cloud Firestore for reports, chats and notifications, Firebase Cloud Messaging for alerts, Cloudinary (free plan) for item photos and avatars, and flutter_map with OpenStreetMap tiles for the campus map.',
        ),
        InfoSection(
          heading: 'Contact',
          body: 'Email: support@smartfind.app\nBug reports: please include a description of what you expected vs. what happened, and the screen name.',
        ),
        InfoSection(
          heading: 'Acknowledgements',
          body: 'Campus building data sourced from the official Kyungsung University website at https://kscms.ks.ac.kr. Map tiles provided by OpenStreetMap contributors. Brand identity designed in-house. Built for the Kyungsung community.',
        ),
      ],
    );
  }
}
