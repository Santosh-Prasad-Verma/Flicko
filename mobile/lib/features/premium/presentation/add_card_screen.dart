import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/clients/supabase_client.dart';

class AddCardScreen extends ConsumerStatefulWidget {
  const AddCardScreen({super.key});

  @override
  ConsumerState<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends ConsumerState<AddCardScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();
  final _cvvFocusNode = FocusNode();

  bool _isSaving = false;
  bool _showBack = false;
  String _cardType = 'CARD';
  String _cardNumber = '•••• •••• •••• ••••';
  String _cardHolder = 'CARDHOLDER NAME';
  String _cardExpiry = 'MM/YY';
  String _cardCvv = '•••';

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  static const Color lime = Color(0xFF52B788);
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF1A1A1A);
  static const Color purple = Color(0xFF9B84EE);

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _cardNumberController.addListener(_updateCardNumber);
    _expiryController.addListener(_updateExpiry);
    _cvvController.addListener(_updateCvv);
    _nameController.addListener(_updateName);

    _cvvFocusNode.addListener(() {
      _flipCard(_cvvFocusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    _cvvFocusNode.dispose();
    super.dispose();
  }

  void _updateCardNumber() {
    final text = _cardNumberController.text;
    final formatted = _formatCardNumber(text);
    if (formatted != text) {
      _cardNumberController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    setState(() {
      _cardNumber = formatted.isNotEmpty ? formatted : '•••• •••• •••• ••••';
      _cardType = _detectCardType(text);
    });
  }

  void _updateExpiry() {
    final text = _expiryController.text;
    final formatted = _formatExpiry(text);
    if (formatted != text) {
      _expiryController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    setState(() {
      _cardExpiry = formatted.isNotEmpty ? formatted : 'MM/YY';
    });
  }

  void _updateCvv() {
    setState(() {
      _cardCvv = _cvvController.text.isNotEmpty ? _cvvController.text : '•••';
    });
  }

  void _updateName() {
    setState(() {
      _cardHolder = _nameController.text.isNotEmpty
          ? _nameController.text.toUpperCase()
          : 'CARDHOLDER NAME';
    });
  }

  String _formatCardNumber(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  String _formatExpiry(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 2) {
      return '${digits.substring(0, 2)}/${digits.substring(2, digits.length > 4 ? 4 : digits.length)}';
    }
    return digits;
  }

  String _detectCardType(String number) {
    final cleanNumber = number.replaceAll(' ', '');
    if (cleanNumber.startsWith(RegExp(r'^4'))) return 'VISA';
    if (cleanNumber.startsWith(RegExp(r'^5[1-5]'))) return 'MASTERCARD';
    if (cleanNumber.startsWith(RegExp(r'^3[47]'))) return 'AMEX';
    if (cleanNumber.startsWith(RegExp(r'^6(?:011|5)'))) return 'DISCOVER';
    return 'CARD';
  }

  Color _getCardColor() {
    switch (_cardType) {
      case 'VISA':
        return const Color(0xFF1A1F71);
      case 'MASTERCARD':
        return const Color(0xFFEB001B);
      case 'AMEX':
        return const Color(0xFF006FCF);
      case 'DISCOVER':
        return const Color(0xFFFF6000);
      default:
        return purple;
    }
  }

  void _flipCard(bool showBack) {
    if (showBack && !_showBack) {
      _flipController.forward();
      setState(() => _showBack = true);
    } else if (!showBack && _showBack) {
      _flipController.reverse();
      setState(() => _showBack = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: black,
      appBar: AppBar(
        title: Text('ADD CARD', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 16, color: white)),
        backgroundColor: black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: white),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _build3DCard(),
              const SizedBox(height: 40),
              _buildInputSection(),
              const SizedBox(height: 32),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _build3DCard() {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final angle = _flipAnimation.value * 3.14159;
        final showBack = _flipAnimation.value > 0.5;
        
        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          alignment: Alignment.center,
          child: showBack
              ? Transform(
                  transform: Matrix4.identity()..rotateY(3.14159),
                  alignment: Alignment.center,
                  child: _buildCardBack(),
                )
              : _buildCardFront(),
        );
      },
    );
  }

  Widget _buildCardFront() {
    final cardColor = _getCardColor();
    
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cardColor, cardColor.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cardColor.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned.fill(
            child: CustomPaint(
              painter: _CardPatternPainter(),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(Icons.credit_card, color: white.withValues(alpha: 0.8), size: 32),
                    Text(
                      _cardType,
                      style: GoogleFonts.spaceGrotesk(
                        color: white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  _cardNumber,
                  style: GoogleFonts.robotoMono(
                    color: white,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CARD HOLDER',
                            style: GoogleFonts.spaceGrotesk(
                              color: white.withValues(alpha: 0.6),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _cardHolder,
                            style: GoogleFonts.spaceGrotesk(
                              color: white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'EXPIRES',
                          style: GoogleFonts.spaceGrotesk(
                            color: white.withValues(alpha: 0.6),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _cardExpiry,
                          style: GoogleFonts.spaceGrotesk(
                            color: white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack() {
    final cardColor = _getCardColor();
    
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cardColor, cardColor.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cardColor.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 30),
          // Magnetic strip
          Container(
            height: 50,
            color: black.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 30),
          // CVV section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.only(right: 12),
                    alignment: Alignment.centerRight,
                    child: Text(
                      _cardCvv,
                      style: GoogleFonts.robotoMono(
                        color: cardColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'The CVV is the 3-digit security code on the back of your card.',
              style: GoogleFonts.spaceGrotesk(
                color: white.withValues(alpha: 0.5),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Column(
      children: [
        _buildTextField(
          controller: _cardNumberController,
          label: 'Card Number',
          hint: '1234 5678 9012 3456',
          keyboardType: TextInputType.number,
          maxLength: 19,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) {
            if (v == null || v.isEmpty) return 'Card number required';
            final digits = v.replaceAll(' ', '');
            if (digits.length < 13) return 'Invalid card number';
            if (!_isValidLuhn(digits)) return 'Invalid card number (Luhn check failed)';
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _expiryController,
                label: 'Expiry Date',
                hint: 'MM/YY',
                keyboardType: TextInputType.number,
                maxLength: 5,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Expiry required';
                  if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(v)) return 'Use MM/YY format';
                  final parts = v.split('/');
                  final month = int.tryParse(parts[0]) ?? 0;
                  if (month < 1 || month > 12) return 'Invalid month';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _cvvController,
                label: 'CVV',
                hint: '123',
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                focusNode: _cvvFocusNode,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'CVV required';
                  if (v.length < 3) return 'Invalid CVV';
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _nameController,
          label: 'Cardholder Name',
          hint: 'JOHN DOE',
          textCapitalization: TextCapitalization.characters,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Name required';
            if (v.length < 2) return 'Name too short';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    FocusNode? focusNode,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            color: white.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          validator: validator,
          style: GoogleFonts.spaceGrotesk(color: white, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.spaceGrotesk(color: white.withValues(alpha: 0.3)),
            filled: true,
            fillColor: grey,
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: lime, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isSaving ? null : _saveCard,
      style: ElevatedButton.styleFrom(
        backgroundColor: lime,
        foregroundColor: black,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _isSaving
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(color: black, strokeWidth: 2),
            )
          : Text(
              'SAVE CARD',
              style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w900),
            ),
    );
  }

  bool _isValidLuhn(String number) {
    int sum = 0;
    bool alternate = false;
    for (int i = number.length - 1; i >= 0; i--) {
      int digit = int.parse(number[i]);
      if (alternate) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  Future<void> _saveCard() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      final cardNumber = _cardNumberController.text.replaceAll(' ', '');
      final exp = _expiryController.text.split('/');

      await Supabase.instance.client.from('payment_methods').insert({
        'user_id': user.id,
        'card_number_last_four': cardNumber.substring(cardNumber.length - 4),
        'card_type': _cardType,
        'expiry_month': int.parse(exp[0]),
        'expiry_year': int.parse('20${exp[1]}'),
        'cardholder_name': _nameController.text.toUpperCase(),
        'is_default': true,
      });

      // Set other cards to not default
      await Supabase.instance.client
          .from('payment_methods')
          .update({'is_default': false})
          .eq('user_id', user.id)
          .neq('card_number_last_four', cardNumber.substring(cardNumber.length - 4));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Card added successfully'),
            backgroundColor: lime,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _CardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 20; i++) {
      final y = i * 15.0;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
