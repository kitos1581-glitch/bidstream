import 'package:flutter/material.dart';

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Centro de ayuda público (no requiere cuenta): cómo comprar y vender,
/// comisiones, entregas, problemas, términos y privacidad.
class HelpCenterWidget extends StatelessWidget {
  const HelpCenterWidget({super.key, this.topic = ''});

  /// Tema a abrir de inicio: comprar | vender | comisiones | entregas |
  /// problemas | terminos | privacidad.
  final String topic;

  static String routeName = 'HelpCenter';
  static String routePath = '/ayuda';

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: theme.secondaryBackground,
        surfaceTintColor: Colors.transparent,
        title: Text('Ayuda', style: theme.titleLarge.copyWith(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.goNamed('AuctionDashboard'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Text('¿Cómo funciona Subástalo Aquí?',
                  style: theme.headlineSmall.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                'Ver subastas es gratis y no necesitas cuenta. Te pedimos registrarte '
                'solo cuando quieras pujar o publicar.',
                style: theme.bodyMedium.copyWith(color: theme.secondaryText),
              ),
              const SizedBox(height: 16),
              for (final t in kHelpTopics)
                _TopicCard(topic: t, initiallyExpanded: t.id == topic),
              const SizedBox(height: 16),
              Text(
                'Versión preliminar. Las reglas completas están en el reglamento, '
                'que se publicará después de su revisión legal.',
                style: theme.bodySmall.copyWith(color: theme.secondaryText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HelpTopic {
  const HelpTopic(this.id, this.icon, this.title, this.points);
  final String id;
  final IconData icon;
  final String title;
  final List<String> points;
}

const kHelpTopics = <HelpTopic>[
  HelpTopic('comprar', Icons.gavel_rounded, 'Cómo comprar', [
    'Busca y revisa el lote: fotos, estado, características y tiempo restante.',
    'Para pujar crea tu cuenta, verifica tu correo y deja un depósito de garantía de \$200 (se descuenta si ganas).',
    'Escribe el máximo que estás dispuesto a pagar. Es secreto: el sistema puja por ti solo lo necesario para ir ganando.',
    'Si alguien puja en los últimos 30 segundos, el cierre se alarga 30 segundos para que todos puedan responder.',
    'Algunos lotes por tiempo tienen precio de reserva (secreto): verás "Reserva no alcanzada" o "alcanzada". Si al cerrar no se alcanzó, no hay venta y no pagas nada.',
    'Una puja es un compromiso de compra: no se puede retirar.',
    'Si ganas, tienes 24 horas para pagar con Mercado Pago. Después recibes el contacto del vendedor para la entrega.',
  ]),
  HelpTopic('vender', Icons.sell_outlined, 'Cómo vender', [
    'Para vender necesitas verificar tu identidad con tu INE (una sola vez).',
    'Sube de 1 a 10 fotos reales del artículo. La IA puede ayudarte a escribir título y descripción; tú revisas todo antes de publicar.',
    'Llena las características obligatorias de tu categoría (por ejemplo: factura y REPUVE en vehículos, arete SINIIGA y guía en ganado). Lo que declares es parte de la oferta.',
    'Tú pones el precio inicial y el incremento mínimo. Elige subasta por tiempo (1 a 7 días) o en vivo con transmisión de YouTube.',
    'En subastas por tiempo puedes poner un precio de reserva secreto: empieza con un precio inicial bajo para atraer pujas y no vendes por debajo de tu mínimo. Con pujas solo puedes bajarla.',
    'Publicar es gratis. Solo pagas comisión si se vende y el comprador paga.',
    'No pongas teléfonos ni redes en la publicación: los contactos se comparten después del pago.',
  ]),
  HelpTopic('comisiones', Icons.percent_rounded, 'Comisiones', [
    'La paga el vendedor, solo cuando hay venta pagada. Al comprador no se le cobra comisión.',
    'Es por tramos: 10% de los primeros \$10,000, 8% de \$10,000 a \$100,000 y 6% de lo que pase de \$100,000. Mínimo \$50.',
    'Ejemplos: venta de \$5,000 → comisión \$500. Venta de \$50,000 → \$4,200. Venta de \$300,000 → \$20,200.',
    'La tarifa de Mercado Pago ya está incluida en la comisión.',
  ]),
  HelpTopic('entregas', Icons.local_shipping_outlined, 'Entregas', [
    'Cuando el comprador paga, ambos reciben el contacto del otro para coordinar la entrega.',
    'El flete y los trámites de traslado los paga el comprador, salvo que la publicación diga otra cosa.',
    'El vendedor entrega con los documentos que declaró (factura, guía, aretes, etc.).',
    'Recomendación: entrega en un lugar público o en el domicilio declarado, de día, y revisa el artículo antes de llevártelo.',
  ]),
  HelpTopic('problemas', Icons.support_agent_outlined, 'Si el vendedor no entrega o el artículo llega distinto', [
    'Tu pago queda retenido: el vendedor lo recibe cuando confirmas que te llegó bien, o a los 7 días si no reclamas.',
    'Mientras el pago siga retenido puedes reclamar desde la app, con fotos.',
    'Aplica si no llegó, si no coincide con las fotos, el estado o las características declaradas, si faltan documentos o si tiene un defecto que no se dijo.',
    'Mientras haya un reclamo, el pago al vendedor queda retenido. El equipo revisa y decide: reembolso total, parcial o liberar el pago.',
    'El vendedor que pierde un reclamo (reembolso total) recibe un strike; con dos, se suspende su cuenta.',
    'Si el ganador no paga, pierde su depósito de \$200 (se entrega al vendedor) y recibe un strike.',
    'Paga siempre dentro de la app: un pago "por fuera" no está protegido.',
  ]),
  HelpTopic('terminos', Icons.description_outlined, 'Términos y reglas', [
    'Solo mayores de 18 años, una cuenta por persona.',
    'Prohibido: armas, drogas y medicamentos controlados, animales silvestres protegidos, vehículos con reporte de robo o sin documentos, artículos robados o falsificados, documentos oficiales.',
    'El vendedor no puede pujar en sus propios lotes ni pedir a otros que lo hagan.',
    'La plataforma puede cancelar publicaciones que violen las reglas y suspender cuentas por fraude.',
    'Todos los montos son en pesos mexicanos.',
  ]),
  HelpTopic('privacidad', Icons.lock_outline_rounded, 'Privacidad', [
    'Las fotos de tu INE y tu selfie son privadas: solo las ve el equipo que las revisa, y solo se usan para verificar tu identidad.',
    'Tu puja máxima es secreta: nadie la ve, ni el vendedor.',
    'En el historial público solo aparece tu nombre y la inicial de tu apellido (por ejemplo, "Juan P.").',
    'Tu teléfono y nombre completo se comparten solo con tu contraparte y solo después del pago.',
  ]),
];

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic, required this.initiallyExpanded});
  final HelpTopic topic;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.alternate),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Icon(topic.icon, color: theme.primary),
          title: Text(topic.title,
              style: theme.titleMedium.copyWith(fontWeight: FontWeight.w700)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: [
            for (final p in topic.points)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 10),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: theme.tertiary, shape: BoxShape.circle),
                    ),
                  ),
                  Expanded(child: Text(p, style: theme.bodyMedium)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fila de ligas a la ayuda, para el pie de pantallas públicas.
class HelpLinks extends StatelessWidget {
  const HelpLinks({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    Widget link(String label, String topic) => TextButton(
          style: TextButton.styleFrom(
              foregroundColor: theme.secondaryText,
              padding: const EdgeInsets.symmetric(horizontal: 8)),
          onPressed: () => context.pushNamed('HelpCenter',
              queryParameters: {'tema': topic}),
          child: Text(label, style: theme.bodySmall.copyWith(decoration: TextDecoration.underline)),
        );
    return Container(
      width: double.infinity,
      color: theme.secondaryContainer,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
      child: Column(children: [
        Wrap(alignment: WrapAlignment.center, children: [
          link('Cómo comprar', 'comprar'),
          link('Cómo vender', 'vender'),
          link('Comisiones', 'comisiones'),
          link('Entregas', 'entregas'),
          link('Si algo sale mal', 'problemas'),
          link('Términos', 'terminos'),
          link('Privacidad', 'privacidad'),
        ]),
        const SizedBox(height: 4),
        Text('© Subástalo Aquí · Precios en pesos mexicanos (MXN)',
            style: theme.bodySmall.copyWith(color: theme.secondaryText)),
      ]),
    );
  }
}

/// Tres pasos de "cómo funciona" para el inicio.
class HowItWorks extends StatelessWidget {
  const HowItWorks({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final steps = [
      (Icons.search_rounded, 'Explora sin cuenta', 'Fotos, precio actual y tiempo restante a la vista.'),
      (Icons.gavel_rounded, 'Puja con tu máximo secreto', 'El sistema puja por ti. Depósito de \$200 que se descuenta si ganas.'),
      (Icons.verified_user_outlined, 'Paga protegido', 'Pagas en la app; si no llega o llega distinto, reclamas.'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth > 640;
          final cards = [
            for (final s in steps)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(s.$1, color: theme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.$2, style: theme.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(s.$3, style: theme.bodySmall),
                    ]),
                  ),
                ]),
              ),
          ];
          return wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: cards[i]),
                  ],
                ])
              : Column(children: [
                  for (final c in cards) ...[c, const SizedBox(height: 8)],
                ]);
        }),
        TextButton(
          onPressed: () => context.pushNamed('HelpCenter'),
          child: const Text('Ver cómo funciona todo →'),
        ),
      ]),
    );
  }
}
