import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/domain/sms/sms_processor.dart';
import 'package:pesaflow/domain/sms/provider_matcher.dart';
import 'package:pesaflow/domain/sms/parsers/sms_parser_interface.dart';
import 'package:pesaflow/domain/sms/provider_config.dart';
import 'package:pesaflow/domain/sms/sms_classifier.dart';
import 'package:pesaflow/domain/sms/deduplicator.dart';
import 'package:pesaflow/domain/sms/parsers/generic_fallback_parser.dart';
import 'package:pesaflow/domain/sms/models/sms_parsed.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';

class SmsParserDebugScreen extends ConsumerStatefulWidget {
  const SmsParserDebugScreen({super.key});

  @override
  ConsumerState<SmsParserDebugScreen> createState() => _SmsParserDebugScreenState();
}

class _SmsParserDebugScreenState extends ConsumerState<SmsParserDebugScreen> {
  final _senderController = TextEditingController(text: 'SELCOM');
  final _bodyController = TextEditingController(
    text:
        '0517EQMYW Confirmed. You have received TZS 473,000.00 from ELISHA NDUNDULU - Mixx by Yas (255675259341) on 2026-05-17 17:57:46. Updated balance is TZS 477,319.85.',
  );
  final _timestampController = TextEditingController(
    text: DateTime.now().millisecondsSinceEpoch.toString(),
  );

  String _output = 'Enter sender, body, timestamp (ms) and tap "Run Pipeline"';
  bool _running = false;

  Future<void> _runPipeline() async {
    setState(() {
      _running = true;
      _output = 'Running pipeline...\n';
    });

    final sender = _senderController.text.trim();
    final body = _bodyController.text.trim();
    final timestampMs = int.tryParse(_timestampController.text.trim()) ?? DateTime.now().millisecondsSinceEpoch;
    final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);

    final buffer = StringBuffer();

    void log(String msg) {
      buffer.writeln(msg);
      setState(() => _output = buffer.toString());
    }

    // ── Step 1: Provider Matching ──
    log('═══ STEP 1: ProviderMatcher ═══');
    final provider = ProviderMatcher.matchProvider(sender, body: body);
    log('Sender: "$sender"');
    log('Provider: ${provider ?? '❌ NULL (no match)'}');
    if (provider == null) {
      log('→ STOPPED: Unknown provider');
      setState(() => _running = false);
      return;
    }

    // ── Step 2: Primary Parser ──
    log('\n═══ STEP 2: Primary Parser ═══');
    final parser = ProviderRegistry.parserFor(provider);
    log('Parser: ${parser.runtimeType}');
    final primaryResult = parser.parse(body, timestamp);
    log('Result: ${primaryResult != null ? '✅ PARSED' : '❌ NULL'}');
    if (primaryResult != null) {
      _logParsed(primaryResult, log);
      log('\n→ SUCCESS: Primary parser handled it');
      setState(() => _running = false);
      return;
    }

    // ── Step 3: Classifier (what fallback sees) ──
    log('\n═══ STEP 3: SmsClassifier (fallback gate) ═══');
    final classification = SmsClassifier.classify(body);
    log('Label: ${classification.label}');
    log('Confidence: ${classification.transactionConfidence.toStringAsFixed(3)}');
    log('Reasons: ${classification.reasons.join('; ')}');
    if (!classification.isTransaction) {
      log('→ STOPPED: Classifier rejected as ${classification.label}');
      setState(() => _running = false);
      return;
    }

    // ── Step 4: Generic Fallback Parser ──
    log('\n═══ STEP 4: GenericFallbackParser ═══');
    final fallback = ProviderRegistry.fallbackFor(provider);
    final fallbackResult = fallback.parse(body, timestamp);
    log('Result: ${fallbackResult != null ? '✅ PARSED' : '❌ NULL'}');
    if (fallbackResult != null) {
      _logParsed(fallbackResult, log);
      log('\n→ SUCCESS: Fallback parser handled it');
      setState(() => _running = false);
      return;
    }

    log('\n→ FAILED: All parsers returned null');
    setState(() => _running = false);
  }

  void _logParsed(SmsParsed sms, void Function(String) log) {
    log('  Amount: ${CurrencyFormatter.formatCents(sms.amount)}');
    log('  Type: ${sms.type}');
    log('  Counterparty: ${sms.senderOrRecipient}');
    log('  Reference: ${sms.reference}');
    log('  Provider: ${sms.provider}');
    log('  Balance: ${sms.balanceAfter != null ? CurrencyFormatter.formatCents(sms.balanceAfter!) : 'N/A'}');
    log('  Timestamp: ${sms.timestamp}');
  }

  @override
  void dispose() {
    _senderController.dispose();
    _bodyController.dispose();
    _timestampController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SMS Parser Debug')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _senderController,
              decoration: const InputDecoration(labelText: 'Sender (shortcode)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(labelText: 'SMS Body'),
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _timestampController,
              decoration: const InputDecoration(labelText: 'Timestamp (ms since epoch)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _running ? null : _runPipeline,
                child: _running
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Run Full Pipeline'),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _output,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.greenAccent,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _presetButton('Selcom Income', 'SELCOM',
                    '0517EQMYW Confirmed. You have received TZS 473,000.00 from ELISHA NDUNDULU - Mixx by Yas (255675259341) on 2026-05-17 17:57:46. Updated balance is TZS 477,319.85.'),
                _presetButton('Selcom Expense', 'SELCOM',
                    '0517EQN0Z Accepted. You have sent TZS 477,000.00 to PARTS AND COMPONENTS MBEYA - 19938686 on 2026-05-17 17:58:34. Charge is FREE. Updated balance is TZS 319.85.'),
                _presetButton('M-Pesa Sw Income', 'M-PESA',
                    'Pesa zimewekwa Tsh 50,000.00 na John Doe tarehe 15/5/2026. Rej: P65AB. Salio: Tsh 250,000.00'),
                _presetButton('M-Pesa Eng Income', 'M-PESA',
                    'Z10DN636 Confirmed.You have received Tsh50,000 from FREDRICK KIMARO on 27/1/14 at 1:19 PM New M-PESA balance is Tsh214,676'),
                _presetButton('Airtel Sw Sent', 'AIRTEL',
                    'Umetuma Tsh 20,000.00 kwa 0765432198. Rej: AT654321. Salio: Tsh 280,000.00'),
                _presetButton('Tigo Mixx Eng Sent', 'MIXX',
                    'ABC123DF Confirmed. Tsh 150,000.00 sent to TIPS-Mixx By Yas for account 255763559341 on 3/6/26. Balance is Tsh2,561.00'),
                _presetButton('NMB New Format', 'NMB',
                    'Kumb: GWX102246282556 Imethibitishwa.\nKiasi cha TSH334,500 kimetumwa kutoka katika akaunti inayoishia na 1222 kwenda ELISHA NDUNDULU 255763559341.\nTarehe:10-06-2026 20:11:13. Teleza Kidigitali na Mshiko Fasta'),
                _presetButton('Promo (should reject)', 'SELCOM',
                    'Get 100% bonus on your next recharge! Dial *150*00# to win TSH 1,000,000. Visit www.selcom.co.tz'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetButton(String label, String sender, String body) {
    return OutlinedButton(
      onPressed: () {
        _senderController.text = sender;
        _bodyController.text = body;
        _timestampController.text = DateTime.now().millisecondsSinceEpoch.toString();
      },
      child: Text(label),
    );
  }
}

// Extension to make it easy to push from anywhere
extension SmsParserDebugExtension on BuildContext {
  void openSmsParserDebug() {
    Navigator.of(this).push(
      MaterialPageRoute(builder: (_) => const SmsParserDebugScreen()),
    );
  }
}