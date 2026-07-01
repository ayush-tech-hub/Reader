import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Approximate currency converter with static base rates (USD base).
/// Rates are approximate and may not reflect live market values.
class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  State<CurrencyConverterScreen> createState() =>
      _CurrencyConverterScreenState();
}

// Static rates relative to USD (1 USD = X of this currency)
const _rates = <String, double>{
  'USD': 1.0,
  'EUR': 0.92,
  'GBP': 0.79,
  'JPY': 149.50,
  'CAD': 1.36,
  'AUD': 1.55,
  'CHF': 0.88,
  'CNY': 7.24,
  'INR': 83.50,
  'MXN': 17.10,
  'BRL': 4.97,
  'KRW': 1325.0,
  'SGD': 1.34,
  'HKD': 7.82,
  'NOK': 10.60,
  'SEK': 10.35,
  'DKK': 6.88,
  'NZD': 1.63,
  'ZAR': 18.60,
  'TRY': 32.0,
  'AED': 3.67,
  'SAR': 3.75,
  'IDR': 15700.0,
  'THB': 35.20,
  'MYR': 4.72,
  'PHP': 56.70,
  'PKR': 278.0,
  'BDT': 110.0,
  'NGN': 1570.0,
  'EGP': 30.90,
  'PLN': 3.98,
  'CZK': 22.60,
  'HUF': 355.0,
  'RON': 4.57,
  'RUB': 92.0,
  'UAH': 39.0,
  'ILS': 3.65,
  'VND': 24400.0,
  'TWD': 31.50,
  'CLP': 910.0,
  'ARS': 870.0,
  'COP': 3960.0,
  'PEN': 3.72,
  'KES': 130.0,
};

const _symbols = <String, String>{
  'USD': '\$', 'EUR': '€', 'GBP': '£', 'JPY': '¥',
  'CAD': 'C\$', 'AUD': 'A\$', 'CHF': 'Fr', 'CNY': '¥',
  'INR': '₹', 'MXN': 'Mex\$', 'BRL': 'R\$', 'KRW': '₩',
  'SGD': 'S\$', 'HKD': 'HK\$', 'NZD': 'NZ\$', 'ZAR': 'R',
  'TRY': '₺', 'AED': 'د.إ', 'SAR': '﷼', 'THB': '฿',
  'PHP': '₱', 'NGN': '₦', 'EGP': '£', 'PLN': 'zł',
  'HUF': 'Ft', 'ILS': '₪', 'VND': '₫', 'CLP': '\$',
  'ARS': '\$', 'COP': '\$', 'PEN': 'S/',
};

String _sym(String code) => _symbols[code] ?? code;

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  final _amountCtrl = TextEditingController(text: '1');
  String _from = 'USD';
  String _to = 'EUR';
  final List<String> _currencies = _rates.keys.toList()..sort();

  double _convert(double amount, String from, String to) {
    final inUsd = amount / (_rates[from] ?? 1);
    return inUsd * (_rates[to] ?? 1);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final result = _convert(amount, _from, _to);

    return Scaffold(
      appBar: AppBar(title: const Text('Currency Converter')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Amount input
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '${_sym(_from)} ',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            // From / To selectors
            Row(
              children: [
                Expanded(child: _CurrencyDrop(_from, _currencies, (v) => setState(() => _from = v!))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: IconButton.outlined(
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: () => setState(() {
                      final tmp = _from;
                      _from = _to;
                      _to = tmp;
                    }),
                  ),
                ),
                Expanded(child: _CurrencyDrop(_to, _currencies, (v) => setState(() => _to = v!))),
              ],
            ),
            const SizedBox(height: 24),
            // Result
            Card(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      '${_sym(_from)} ${_fmtAmount(amount)} =',
                      style: TextStyle(color: scheme.onPrimaryContainer),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _fmtAmount(result)));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied')));
                      },
                      child: Text(
                        '${_sym(_to)} ${_fmtAmount(result)}',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.onPrimaryContainer,
                            ),
                      ),
                    ),
                    Text(_to,
                        style: TextStyle(
                            color: scheme.onPrimaryContainer.withOpacity(0.7))),
                    const SizedBox(height: 4),
                    Text(
                      '1 $_from = ${_fmtAmount(_convert(1, _from, _to))} $_to',
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onPrimaryContainer.withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Quick conversions
            Text('Quick conversions from ${_sym(_from)}$_from:',
                style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final to in ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'INR',
                                    'AUD', 'CHF', 'CNY', 'SGD']
                      .where((c) => c != _from))
                    ListTile(
                      dense: true,
                      title: Text('$to (${_sym(to)})'),
                      trailing: Text(
                        '${_sym(to)} ${_fmtAmount(_convert(amount, _from, to))}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () => setState(() => _to = to),
                    ),
                ],
              ),
            ),
            Text(
              'Rates are approximate and for reference only. Not for financial use.',
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _fmtAmount(double v) {
    if (v.abs() >= 100) return v.toStringAsFixed(2);
    if (v.abs() >= 1) return v.toStringAsFixed(4);
    return v.toStringAsFixed(6);
  }
}

class _CurrencyDrop extends StatelessWidget {
  const _CurrencyDrop(this.value, this.currencies, this.onChanged);
  final String value;
  final List<String> currencies;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        value: value,
        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
        items: currencies
            .map((c) => DropdownMenuItem(
                  value: c,
                  child: Text('$c (${_sym(c)})',
                      overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: onChanged,
      );
}
