import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/erros/falha_app.dart';
import '../../core/log/registro_log.dart';
import '../../utils/app_theme.dart';
import 'validar_page.dart' show entenderCodigo;

const _chave = 'rh.validar';

/// Leitor de QR Code de Validar documento: a câmera em tela cheia com a
/// moldura no meio. Lê só QR Code; quando acha um código de documento da
/// PMRR (o mesmo que [entenderCodigo] aceita), vibra e devolve o texto lido.
/// QR que não é da PMRR mostra o aviso sem fechar, para tentar de novo.
class LeitorQrPage extends StatefulWidget {
  const LeitorQrPage({super.key});

  @override
  State<LeitorQrPage> createState() => _LeitorQrPageState();
}

class _LeitorQrPageState extends State<LeitorQrPage> {
  final _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _lido = false;
  String? _aviso;

  @override
  void initState() {
    super.initState();
    registrar('documento.qr_abrir', chave: _chave);
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  void _aoLer(BarcodeCapture captura) {
    if (_lido) return;
    final texto = captura.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (texto == null) return;
    if (entenderCodigo(texto) == null) {
      registrar('documento.qr_ler', chave: _chave, resultado: 'falhou', codigo: 'VD-QR-OUTRO');
      setState(() => _aviso = 'Este QR Code não é de um documento da PMRR. Aponte para o QR da certidão ou do '
          'contracheque. Código VD-QR-OUTRO.');
      return;
    }
    _lido = true;
    HapticFeedback.mediumImpact();
    registrar('documento.qr_ler', chave: _chave, resultado: 'ok');
    Navigator.of(context).pop(texto);
  }

  /// Sem câmera (permissão negada, simulador, aparelho sem câmera): o motivo
  /// e o que fazer, com código; o militar volta e digita o código.
  Widget _erro(BuildContext context, MobileScannerException e) {
    final semPermissao = e.errorCode == MobileScannerErrorCode.permissionDenied;
    final f = FalhaApp(
      codigo: semPermissao ? 'VD-CAMERA-PERMISSAO' : 'VD-CAMERA',
      origem: OrigemFalha.aparelho,
      titulo: semPermissao ? 'O app não tem acesso à câmera' : 'Não foi possível abrir a câmera',
      texto: semPermissao
          ? 'Libere a câmera para o SouPMRR nos ajustes do aparelho e tente de novo, ou volte e digite o código '
              'impresso no documento.'
          : 'Volte e digite o código impresso no documento. Se continuar, abra um chamado técnico com o código.',
      detalhe: '${e.errorCode} ${e.errorDetails?.message ?? ''}',
    );
    registrarErro(f, tela: _chave);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.no_photography_outlined, size: AppIconSize.xl, color: Colors.white),
          const SizedBox(height: 14),
          Text(f.titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 8),
          Text('${f.texto} Código ${f.codigo}.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.4, color: Colors.white.withValues(alpha: .82))),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Digitar o código')),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lado = (MediaQuery.sizeOf(context).shortestSide * .66).clamp(200.0, 320.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(fit: StackFit.expand, children: [
          MobileScanner(controller: _camera, onDetect: _aoLer, errorBuilder: _erro),
          // Véu escuro com a janela da moldura e os cantos; somem quando a
          // câmera falha, para não ficarem por cima da explicação.
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _camera,
            builder: (context, estado, _) => estado.error != null
                ? const SizedBox.shrink()
                : IgnorePointer(
                    child: Stack(fit: StackFit.expand, children: [
                      CustomPaint(painter: _Veu(lado: lado, raio: 22)),
                      Center(
                        child: SizedBox(
                          width: lado,
                          height: lado,
                          child: CustomPaint(painter: _Cantos(cor: const Color(0xFF4FD8F0))),
                        ),
                      ),
                    ]),
                  ),
          ),
          SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(children: [
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: AppIconSize.md),
                  ),
                  const Expanded(
                    child: Text('Ler QR Code',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                  ValueListenableBuilder<MobileScannerState>(
                    valueListenable: _camera,
                    builder: (context, estado, _) => IconButton(
                      tooltip: estado.torchState == TorchState.on ? 'Apagar a lanterna' : 'Acender a lanterna',
                      onPressed: estado.torchState == TorchState.unavailable ? null : _camera.toggleTorch,
                      icon: Icon(
                          estado.torchState == TorchState.on
                              ? Icons.flashlight_off_rounded
                              : Icons.flashlight_on_rounded,
                          color: Colors.white,
                          size: AppIconSize.md),
                    ),
                  ),
                ]),
              ),
              const Spacer(),
              ValueListenableBuilder<MobileScannerState>(
                valueListenable: _camera,
                builder: (context, estado, filho) => estado.error != null ? const SizedBox.shrink() : filho!,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      _aviso ?? 'Aponte para o QR Code impresso na certidão ou no contracheque.',
                      key: ValueKey(_aviso),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.4,
                        color: _aviso == null ? Colors.white : const Color(0xFFFFC968),
                        fontWeight: _aviso == null ? FontWeight.w500 : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Veu extends CustomPainter {
  _Veu({required this.lado, required this.raio});
  final double lado;
  final double raio;

  @override
  void paint(Canvas canvas, Size size) {
    final janela = RRect.fromRectAndRadius(
        Rect.fromCenter(center: size.center(Offset.zero), width: lado, height: lado), Radius.circular(raio));
    final caminho = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(janela);
    canvas.drawPath(caminho, Paint()..color = Colors.black.withValues(alpha: .55));
  }

  @override
  bool shouldRepaint(_Veu old) => old.lado != lado;
}

class _Cantos extends CustomPainter {
  _Cantos({required this.cor});
  final Color cor;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = cor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const t = 30.0, r = 22.0;
    final w = s.width, h = s.height;
    for (final (x, y, dx, dy) in [(0.0, 0.0, 1.0, 1.0), (w, 0.0, -1.0, 1.0), (0.0, h, 1.0, -1.0), (w, h, -1.0, -1.0)]) {
      final c = Path()
        ..moveTo(x, y + dy * (r + t))
        ..lineTo(x, y + dy * r)
        ..arcToPoint(Offset(x + dx * r, y), radius: const Radius.circular(r), clockwise: dx * dy > 0)
        ..lineTo(x + dx * (r + t), y);
      canvas.drawPath(c, p);
    }
  }

  @override
  bool shouldRepaint(_Cantos old) => old.cor != cor;
}
