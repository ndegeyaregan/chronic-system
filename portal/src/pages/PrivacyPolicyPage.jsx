import { useEffect } from 'react';
import sanlamLogo from '../assets/sanlam-logo.png';

const LAST_UPDATED = '18 May 2026';
const CONTACT_EMAIL = 'it@ug.sanlamallianz.com';
const COMPANY = 'Sanlam Allianz Life Insurance (Uganda) Limited';
const APP_NAME = 'SanCare+';

export default function PrivacyPolicyPage() {
  useEffect(() => {
    document.title = `${APP_NAME} — Privacy Policy`;
  }, []);

  return (
    <div style={{
      minHeight: '100vh',
      background: '#f4f6fb',
      fontFamily: "'Inter', 'Segoe UI', sans-serif",
      color: '#1f2937',
    }}>
      {/* Header */}
      <div style={{
        background: 'linear-gradient(150deg, #003DA5 0%, #0055cc 55%, #003080 100%)',
        color: 'white',
        padding: '32px 20px 28px',
        textAlign: 'center',
      }}>
        <img src={sanlamLogo} alt="Sanlam Allianz"
             style={{ height: 60, marginBottom: 14, filter: 'brightness(0) invert(1)' }} />
        <h1 style={{ margin: 0, fontSize: 28, fontWeight: 800, letterSpacing: '-0.5px' }}>
          Privacy Policy
        </h1>
        <p style={{ margin: '8px 0 0', opacity: 0.85, fontSize: 14 }}>
          {APP_NAME} mobile app · Last updated {LAST_UPDATED}
        </p>
      </div>

      {/* Body */}
      <div style={{
        maxWidth: 820,
        margin: '0 auto',
        padding: '32px 22px 80px',
      }}>
        <div style={{
          background: 'white',
          borderRadius: 16,
          padding: '28px 26px',
          boxShadow: '0 6px 24px rgba(0,0,0,0.05)',
          lineHeight: 1.65,
          fontSize: 15,
        }}>
          <P>
            This Privacy Policy describes how <b>{COMPANY}</b> ("Sanlam Allianz",
            "we", "us") collects, uses, stores, shares and protects personal
            information when you use the <b>{APP_NAME}</b> mobile application
            (the "App"). By installing or using the App you agree to this
            policy. If you do not agree, please do not use the App.
          </P>

          <H2>1. Who we are</H2>
          <P>
            {COMPANY} is a licensed insurer in Uganda and the data controller
            for personal information processed through the App. Our offices
            are in Kampala, Uganda. You can contact us at <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a>.
          </P>

          <H2>2. Information we collect</H2>
          <P>To provide member services and chronic-care support, we collect:</P>
          <Ul items={[
            <><b>Identity & contact data</b> — member number, full name, date of birth, gender, national ID/passport number, phone number, email and postal address (sourced from your Sanlam Allianz medical-scheme record).</>,
            <><b>Authentication data</b> — your account password (stored hashed) and biometric login preference (the biometric template never leaves your device).</>,
            <><b>Health & medical data</b> — chronic conditions on file, medications, prescription history, lab results, vitals you log (blood pressure, glucose, weight, etc.), preauthorisations, claims, appointments and consultations under your medical scheme.</>,
            <><b>Lifestyle & fitness data</b> — steps, walking/running distance, active energy and exercise sessions read from Health Connect (Android) or Apple HealthKit (iOS) with your consent; meals, mood, stress, sleep and water entries you log manually.</>,
            <><b>Location data</b> — approximate or precise device location, used only while you are using the facility-finder or partner-locator features to show nearby clinics, pharmacies and lifestyle partners. We do not track your location in the background.</>,
            <><b>Photos & files</b> — images and documents you choose to attach to claims, reimbursement requests or complaints (e.g. receipts, prescriptions, ID photos for membership cards).</>,
            <><b>Device & diagnostic data</b> — app version, device model, OS version, language, push-notification token, crash logs and anonymous usage events used to keep the App stable.</>,
            <><b>Payment data</b> — when you pay for a service inside the App (e.g. card reprint), we collect the mobile-money phone number and transaction reference. Payment is processed by our partner Pesapal; we do not store full card details.</>,
          ]} />

          <H2>3. How we use your information</H2>
          <Ul items={[
            'Authenticate you and link the App to your Sanlam Allianz medical-scheme membership.',
            'Show your benefits, claims, preauthorisations, dependants and chronic-care profile.',
            'Schedule and remind you of medications, appointments, lab tests and vitals.',
            'Track lifestyle and fitness data so you and your care team can see trends.',
            'Process card reprints, reimbursements and other in-app requests.',
            'Send service notifications (claim status, appointment reminders, scheme updates).',
            'Provide customer support and respond to complaints.',
            'Detect fraud, abuse and security incidents, and meet our legal/regulatory duties.',
            'Improve the App through aggregated, anonymised analytics.',
          ]} />

          <H2>4. Legal basis</H2>
          <P>
            We process your data on the basis of (a) <b>your consent</b> for
            optional features such as health-store access, location and
            biometrics; (b) <b>performance of the insurance contract</b>
            between you and Sanlam Allianz; (c) <b>compliance with legal
            obligations</b> under Ugandan insurance, health and data-protection
            law (including the Data Protection and Privacy Act, 2019); and
            (d) our <b>legitimate interests</b> in operating, securing and
            improving the App.
          </P>

          <H2>5. Health Connect & HealthKit</H2>
          <P>
            With your explicit, in-app consent the App reads the following
            from Health Connect (Android) or Apple HealthKit (iOS):
          </P>
          <Ul items={[
            'Steps — to show your daily activity count.',
            'Distance — to show how far you walked or ran.',
            'Active energy burned — to estimate calories.',
            'Exercise / workouts — to separate walking time from running time.',
          ]} />
          <P>
            We only <b>read</b>, never write. We use this data inside the App
            and, in summary form, store it against your member record so your
            care team can see fitness trends. You can withdraw access at any
            time in your device's Health Connect or Apple Health settings;
            previously synced data already on our servers can be deleted on
            request (see section 11).
          </P>
          <P>
            Data obtained from Health Connect / Apple Health is <b>never</b>
            sold, used for advertising, or shared with third parties outside
            the purposes described in this policy, and is <b>not</b> used to
            derive information about race, sexual orientation, religion or
            political views.
          </P>

          <H2>6. Sharing your data</H2>
          <P>We share personal data only with:</P>
          <Ul items={[
            'Your healthcare providers (hospitals, clinics, pharmacies, labs) on the Sanlam Allianz network, to the extent needed to deliver and adjudicate the services you request.',
            'The Sanlam Allianz claims-administration platform (ehosccs.net) which is the source of truth for your scheme record.',
            'Our IT, cloud-hosting, SMS, email and push-notification providers, bound by confidentiality and data-processing agreements.',
            'Payment processors (Pesapal) for in-app transactions you initiate.',
            'Regulators, courts and law-enforcement agencies where required by law.',
          ]} />
          <P>We do not sell your personal information. We do not show third-party advertising in the App.</P>

          <H2>7. International transfers</H2>
          <P>
            Some of our cloud and notification providers are based outside
            Uganda. Where data is transferred internationally we ensure
            appropriate safeguards (contractual clauses, encryption-in-transit
            and at-rest) in line with the Data Protection and Privacy Act, 2019.
          </P>

          <H2>8. Data retention</H2>
          <P>
            We keep your data for as long as you remain an active member of
            a Sanlam Allianz medical scheme and for the period required by
            insurance, tax and health-regulatory law thereafter (typically up
            to 7 years after the policy ends). App diagnostic logs are kept
            for 90 days.
          </P>

          <H2>9. Security</H2>
          <P>
            Data in transit is protected with TLS 1.2+. Passwords are hashed
            with bcrypt. Sensitive tokens are kept in the device's secure
            storage (Keychain / EncryptedSharedPreferences). Access to
            backend systems is restricted, logged and audited.
          </P>

          <H2>10. Children</H2>
          <P>
            The App is intended for adult medical-scheme principals and
            spouses. Minor dependants are managed by the principal and do not
            log in directly. We do not knowingly collect data from children
            under 13 except through their parent or legal guardian as part of
            the family medical record.
          </P>

          <H2>11. Your rights</H2>
          <P>Under Ugandan data-protection law you have the right to:</P>
          <Ul items={[
            'Access the personal data we hold about you.',
            'Correct inaccurate or incomplete data.',
            'Request deletion of data we no longer need to keep.',
            'Withdraw a consent you previously gave (e.g. revoke health-store access).',
            'Object to or restrict certain processing.',
            'Lodge a complaint with the Personal Data Protection Office (PDPO).',
          ]} />
          <P>
            To exercise any of these rights, email <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a> from
            the address linked to your member record, or write to us via the
            in-app Complaints feature. We respond within 30 days.
          </P>

          <H2>12. Permissions we request on your device</H2>
          <Ul items={[
            <><b>Activity recognition / Motion</b> — to count steps via the pedometer sensor.</>,
            <><b>Health Connect / HealthKit</b> — to read steps, distance, energy and workouts as described above.</>,
            <><b>Location (while in use)</b> — to show nearby facilities; not used in the background.</>,
            <><b>Notifications</b> — for medication, appointment and claim reminders.</>,
            <><b>Camera & photo library</b> — only when you attach a photo to a claim, reimbursement or card-reprint request.</>,
            <><b>Biometrics</b> — for optional fingerprint / face unlock; the biometric template never leaves your device.</>,
            <><b>Microphone</b> — only when you record a voice note inside the chat or complaint feature.</>,
            <><b>Exact alarms</b> — to fire medication reminders at the exact dosing time.</>,
          ]} />

          <H2>13. Changes to this policy</H2>
          <P>
            We may update this policy from time to time. The "Last updated"
            date at the top of this page will reflect the latest revision.
            Material changes will be notified in the App.
          </P>

          <H2>14. Contact us</H2>
          <P>
            Questions or concerns about this policy or your personal data?
            Email <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a> or call our customer-care line listed
            on <a href="https://ug.sanlamallianz.com/" target="_blank" rel="noreferrer">ug.sanlamallianz.com</a>.
          </P>

          <p style={{ marginTop: 28, color: '#6b7280', fontSize: 13 }}>
            © {new Date().getFullYear()} {COMPANY}. All rights reserved.
          </p>
        </div>
      </div>
    </div>
  );
}

function H2({ children }) {
  return (
    <h2 style={{
      marginTop: 28, marginBottom: 8,
      fontSize: 18, fontWeight: 700, color: '#003DA5',
    }}>{children}</h2>
  );
}
function P({ children }) {
  return <p style={{ margin: '0 0 12px' }}>{children}</p>;
}
function Ul({ items }) {
  return (
    <ul style={{ margin: '0 0 14px', paddingLeft: 22 }}>
      {items.map((it, i) => (
        <li key={i} style={{ marginBottom: 6 }}>{it}</li>
      ))}
    </ul>
  );
}
