"""Genera las páginas estáticas de texto (para buscadores e IA) en web/.

Flutter dibuja la app con JavaScript, así que un buscador o una IA casi no
"ve" texto en subastaloaqui.com. Estas páginas son HTML simple, se cargan sin
JavaScript y explican el servicio. Se publican junto con la app.

Uso:  python3 scripts/seo/build_pages.py
Al lanzar (quitar "no indexar"): cambiar NOINDEX a False, regenerar y quitar la
línea <meta name="robots" content="noindex"> de web/index.html.
"""
import html
import json
import pathlib

NOINDEX = True  # ← False el día del lanzamiento público
SITE = "https://subastaloaqui.com"
UPDATED = "2026-11-08"
WEB = pathlib.Path(__file__).resolve().parent.parent.parent / "web"

ORG = {
    "@type": "Organization",
    "@id": f"{SITE}/#organization",
    "name": "Subástalo Aquí",
    "url": SITE,
    "logo": f"{SITE}/icons/Icon-512.png",
    "email": "contacto@subastaloaqui.com",
    "areaServed": ["Camargo", "Delicias", "Meoqui", "Saucillo", "Jiménez", "La Cruz",
                   "San Francisco de Conchos", "Chihuahua"],
    "address": {"@type": "PostalAddress", "addressLocality": "Camargo",
                "addressRegion": "Chihuahua", "addressCountry": "MX"},
    "sameAs": [],  # ← agregar Facebook, Instagram, TikTok y YouTube cuando existan
}

CSS = """
:root{--azul:#1B3A6B;--naranja:#E8862E;--texto:#1d2733;--suave:#5b6675;--fondo:#ffffff;--linea:#e3e7ee}
@media (prefers-color-scheme:dark){:root{--texto:#e8edf3;--suave:#a9b4c2;--fondo:#0f1620;--linea:#263243}}
*{box-sizing:border-box}body{margin:0;font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;color:var(--texto);background:var(--fondo);line-height:1.6}
header,main,footer{max-width:820px;margin:0 auto;padding:16px}
header a.logo{font-weight:800;font-size:1.3rem;color:var(--azul);text-decoration:none}header a.logo span{color:var(--naranja)}
nav a{margin-right:14px;color:var(--suave)}h1{font-size:2rem;line-height:1.2;color:var(--azul)}h2{margin-top:2rem;color:var(--azul)}
@media (prefers-color-scheme:dark){h1,h2,header a.logo{color:#8fb3ff}}
table{border-collapse:collapse;width:100%}th,td{border:1px solid var(--linea);padding:8px;text-align:left;vertical-align:top}
.cta{display:inline-block;background:var(--azul);color:#fff;padding:12px 20px;border-radius:999px;text-decoration:none;font-weight:700;margin:8px 0}
footer{color:var(--suave);font-size:.9rem;border-top:1px solid var(--linea);margin-top:32px}
"""


def page(slug, title, description, body_html, extra_ld=None):
    ld = [{"@context": "https://schema.org", "@graph": [
        ORG,
        {"@type": "WebPage", "@id": f"{SITE}/{slug}", "url": f"{SITE}/{slug}", "name": title,
         "description": description, "inLanguage": "es-MX", "dateModified": UPDATED,
         "publisher": {"@id": f"{SITE}/#organization"}, "author": {"@id": f"{SITE}/#organization"}},
    ]}]
    if extra_ld:
        ld.append(extra_ld)
    robots = '<meta name="robots" content="noindex">\n' if NOINDEX else ""
    scripts = "\n".join(
        f'<script type="application/ld+json">{json.dumps(x, ensure_ascii=False)}</script>' for x in ld)
    return f"""<!doctype html>
<html lang="es-MX">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>
<meta name="description" content="{html.escape(description)}">
{robots}<link rel="canonical" href="{SITE}/{slug}">
<meta property="og:title" content="{html.escape(title)}">
<meta property="og:description" content="{html.escape(description)}">
<meta property="og:image" content="{SITE}/icons/Icon-512.png">
<link rel="icon" type="image/png" href="/favicon.png">
<style>{CSS}</style>
{scripts}
</head>
<body>
<header><a class="logo" href="/">Subástalo <span>Aquí</span></a>
<nav><a href="/como-funciona.html">Cómo funciona</a><a href="/comisiones.html">Comisiones</a><a href="/preguntas-frecuentes.html">Preguntas frecuentes</a></nav></header>
<main>
{body_html}
<p><a class="cta" href="/">Ver subastas y artículos</a></p>
</main>
<footer>Publicado por Subástalo Aquí · Camargo, Chihuahua, México · Actualizado el {UPDATED} ·
<a href="mailto:contacto@subastaloaqui.com">contacto@subastaloaqui.com</a></footer>
</body>
</html>
"""


COMO = """
<h1>Cómo funciona Subástalo Aquí</h1>
<p><strong>Subástalo Aquí</strong> es una plataforma local de subastas y ventas en línea para el centro-sur de
Chihuahua: Camargo, Delicias, Meoqui, Saucillo, Jiménez, La Cruz y San Francisco de Conchos, con vendedores
también en la ciudad de Chihuahua. Cualquier persona o negocio puede vender en subasta o a precio fijo, y el
comprador paga dentro de la plataforma: <strong>su dinero queda protegido hasta que recibe el artículo</strong>.
Es una alternativa segura a comprar y vender en grupos de Facebook y WhatsApp, donde son comunes los compradores
que apartan y no llegan, los comprobantes de pago falsos y los vendedores que rematan por no saber cuánto vale lo
que venden.</p>

<h2>Cómo comprar</h2>
<ol>
<li><strong>Busca el artículo</strong> y revisa fotos, estado, características, ubicación y tiempo restante. Ver el catálogo es gratis y no necesitas cuenta.</li>
<li><strong>Compra directa:</strong> en artículos a precio fijo, o con "Comprar ahora" en una subasta que aún no tiene pujas, te lo apartamos 30 minutos mientras pagas. No necesitas depósito ni INE.</li>
<li><strong>Para pujar</strong> creas tu cuenta, verificas tu correo y dejas un depósito de garantía de $200 que se descuenta si ganas y es reembolsable si no.</li>
<li><strong>Puja con un máximo secreto:</strong> escribes lo más que pagarías y el sistema puja por ti solo lo necesario para ir ganando. Nadie ve tu máximo, ni el vendedor.</li>
<li><strong>Si ganas</strong>, tienes 24 horas para pagar con tarjeta, saldo de Mercado Pago o en efectivo en OXXO y tiendas.</li>
<li><strong>Recibes el artículo</strong> en persona o por envío regional. Tu pago queda retenido hasta que confirmas que llegó bien.</li>
</ol>

<h2>Cómo vender</h2>
<ol>
<li><strong>Verifica tu identidad</strong> con tu INE una sola vez. Así los compradores saben que eres una persona real.</li>
<li><strong>Sube de 1 a 10 fotos reales.</strong> La app puede mejorar la luz de tus fotos y una IA te ayuda a escribir el título y la descripción; tú revisas todo antes de publicar.</li>
<li><strong>Elige cómo vender:</strong> subasta por tiempo (de 1 a 7 días), subasta en vivo con transmisión de YouTube, o precio fijo (de 7 a 60 días).</li>
<li><strong>Protege tu precio:</strong> en subastas puedes poner un precio de reserva secreto; si no se alcanza, no vendes.</li>
<li><strong>Cobra seguro:</strong> el comprador paga en la plataforma. En entregas en persona, recibes tu dinero al capturar el código de 6 dígitos que te da el comprador al recibir.</li>
</ol>
<p>Publicar es gratis. Hasta el 31 de marzo de 2027 vender no cuesta comisión (hasta 30 ventas al mes por vendedor). Consulta los detalles en <a href="/comisiones.html">Comisiones</a>.</p>

<h2>Subastas en vivo</h2>
<p>Los vendedores pueden transmitir en vivo por YouTube: el video se ve dentro de la app junto al botón de pujar,
y también se puede compartir en Facebook. Si alguien puja en los últimos 40 segundos, el cierre se alarga 40
segundos para que todos puedan responder, igual que en una subasta presencial.</p>

<h2>Por qué es seguro</h2>
<ul>
<li><strong>Pago protegido:</strong> el dinero se libera al vendedor cuando el comprador confirma la entrega, o a los 7 días si no hay reclamo.</li>
<li><strong>Vendedores verificados</strong> con INE y con reputación pública (calificaciones y ventas).</li>
<li><strong>Reclamos con fotos</strong> si el artículo no llegó o no coincide con lo publicado: el equipo revisa y puede reembolsar.</li>
<li><strong>Datos privados:</strong> el teléfono y el nombre completo se comparten solo con tu contraparte y solo después del pago.</li>
<li><strong>Sin datos de contacto en las publicaciones:</strong> así nadie te saca de la plataforma y pierdes la protección.</li>
</ul>

<h2>Qué se vende</h2>
<p>Artículos de la región: vehículos y maquinaria, herramienta, ganado y artículos de rancho, artículos para
caballos, electrónica, muebles y hogar, ropa y artículos de comercios locales. Está prohibido vender armas,
drogas y medicamentos controlados, animales silvestres protegidos, artículos robados o falsificados, vehículos
con reporte de robo o sin documentos, y documentos oficiales.</p>
"""

COMISIONES = """
<h1>Comisiones de Subástalo Aquí</h1>
<p>Publicar es gratis. La comisión la paga solo el vendedor y solo cuando la venta se cobra. Al comprador nunca
se le cobra comisión ni cargo extra por pagar con tarjeta: paga exactamente el precio final.</p>

<h2>Periodo de lanzamiento: 0 % hasta el 31 de marzo de 2027</h2>
<p>Hasta el 31 de marzo de 2027 vender no cuesta comisión, hasta 30 ventas al mes por vendedor. Desde la venta 31
del mes aplica la comisión normal. Con 0 % solo se descuenta el costo real que cobra el procesador de pagos por
esa venta (aproximadamente 3 a 3.5 % más $4 con tarjeta), siempre desglosado.</p>

<h2>Comisión normal por tramos</h2>
<table>
<tr><th>Parte del precio de venta</th><th>Comisión</th></tr>
<tr><td>Primeros $10,000</td><td>10 %</td></tr>
<tr><td>De $10,000 a $100,000</td><td>8 %</td></tr>
<tr><td>Lo que pase de $100,000</td><td>6 %</td></tr>
<tr><td>Comisión mínima por venta</td><td>$50</td></tr>
</table>
<p>Funciona como el ISR: cada tramo paga su porcentaje, así no hay saltos al pasar de un tramo a otro.</p>

<h2>Ejemplos</h2>
<table>
<tr><th>Precio de venta</th><th>Comisión</th><th>Recibe el vendedor</th></tr>
<tr><td>$5,000</td><td>$500</td><td>$4,500</td></tr>
<tr><td>$50,000</td><td>$4,200</td><td>$45,800</td></tr>
<tr><td>$300,000</td><td>$20,200</td><td>$279,800</td></tr>
</table>

<h2>Tiendas Oficiales</h2>
<p>Los negocios verificados pueden ser Tienda Oficial: pagan una cuota fija mensual o anual, no pagan comisión por
venta, no tienen límite de ventas y llevan el distintivo "Tienda Oficial". Informes en contacto@subastaloaqui.com.</p>

<h2>Comparación</h2>
<ul>
<li>En grupos de Facebook no hay comisión, pero tampoco protección del pago ni verificación del vendedor.</li>
<li>En los grandes marketplaces nacionales la comisión suele ser mayor y la entrega es por paquetería; aquí la venta es local y se entrega en persona o por envío regional.</li>
</ul>
"""

FAQ = [
    ("¿Qué es Subástalo Aquí?",
     "Una plataforma local de subastas y ventas en línea para el centro-sur de Chihuahua (Camargo, Delicias, Meoqui, Saucillo, Jiménez, La Cruz y San Francisco de Conchos). El comprador paga dentro de la plataforma y su dinero queda protegido hasta que recibe el artículo."),
    ("¿Cuánto cuesta vender?",
     "Publicar es gratis. Hasta el 31 de marzo de 2027 la comisión es 0 % (hasta 30 ventas al mes); solo se descuenta el costo del procesador de pagos. Después, 10 % de los primeros $10,000, 8 % hasta $100,000 y 6 % arriba, con mínimo de $50."),
    ("¿El comprador paga comisión?",
     "No. El comprador paga exactamente el precio final, sin cargos extra por pagar con tarjeta."),
    ("¿Cómo pago?",
     "Con tarjeta de débito o crédito, saldo de Mercado Pago o, si ganaste una subasta, en efectivo en OXXO y tiendas. Siempre dentro de la plataforma: un pago por fuera no está protegido."),
    ("¿Por qué piden un depósito para pujar?",
     "Para que las pujas sean serias. Es de $200, se descuenta si ganas y se puede reembolsar si no tienes subastas activas. Si ganas y no pagas, lo pierdes. Para compras directas no se pide depósito."),
    ("¿Qué pasa si el artículo no llega o no es como en las fotos?",
     "Tu pago sigue retenido y puedes abrir un reclamo con fotos desde la app. El equipo revisa y decide entre reembolso total, parcial o liberar el pago."),
    ("¿Cuándo recibe su dinero el vendedor?",
     "En entregas en persona, al capturar el código de 6 dígitos que le da el comprador al recibir. En envíos, cuando el comprador confirma que llegó bien o a los 7 días si no hay reclamo."),
    ("¿Qué es el cierre de 40 segundos?",
     "Si alguien puja en los últimos 40 segundos, la subasta se alarga 40 segundos más para que todos puedan responder. Así nadie gana con una puja de último segundo."),
    ("¿Qué necesito para vender?",
     "Una cuenta con correo verificado e identificación con INE (una sola vez). Después subes fotos reales, eliges subasta o precio fijo y publicas."),
    ("¿Puedo poner mi teléfono en la publicación?",
     "No. Las publicaciones con teléfono, correo, WhatsApp o redes se pausan automáticamente. Los datos de contacto se comparten después del pago, para proteger a ambas partes."),
    ("¿Hay subastas en vivo?",
     "Sí. El vendedor transmite por YouTube, el video se ve dentro de la app junto al botón de pujar y también se puede compartir en Facebook."),
    ("¿Cuánto tiempo tengo para pagar si gano una subasta?",
     "24 horas desde que cierra la subasta. Si pagas en efectivo en OXXO o tienda, la ficha vence antes de ese plazo. Si no pagas a tiempo, pierdes el depósito y el artículo se le puede ofrecer al siguiente postor."),
    ("¿Cómo funciona la compra directa a precio fijo?",
     "Tocas Comprar ahora y el artículo queda apartado 30 minutos mientras pagas. Si no completas el pago, se libera para otros compradores. No se pide depósito."),
    ("¿Necesito verificar mi identidad para comprar?",
     "Para pujar o comprar basta tu cuenta con correo verificado y el depósito de garantía. Para pujas de $20,000 o más se pide identificación verificada con INE."),
    ("¿Tengo que instalar una aplicación?",
     "No. Subástalo Aquí funciona desde el navegador del celular o la computadora, sin instalar nada. Puedes agregarlo a tu pantalla de inicio como si fuera una app."),
    ("¿Qué no se puede vender?",
     "Armas, drogas y medicamentos controlados, animales silvestres protegidos, artículos robados o falsificados, vehículos con reporte de robo o sin documentos y documentos oficiales."),
]

FAQ_INTRO = """<h1>Preguntas frecuentes</h1>
<p>Respuestas rápidas sobre cómo comprar, vender y pagar en Subástalo Aquí, la plataforma local de subastas del
centro-sur de Chihuahua.</p>

<h2>Subástalo Aquí en cifras</h2>
<table>
<tr><th>Concepto</th><th>Dato</th></tr>
<tr><td>Costo por publicar</td><td>Gratis</td></tr>
<tr><td>Comisión al vendedor hasta el 31 de marzo de 2027</td><td>0 % (hasta 30 ventas al mes)</td></tr>
<tr><td>Comisión normal al vendedor</td><td>10 % / 8 % / 6 % por tramos, mínimo $50</td></tr>
<tr><td>Comisión al comprador</td><td>$0</td></tr>
<tr><td>Depósito para pujar</td><td>$200, reembolsable</td></tr>
<tr><td>Plazo para pagar una subasta ganada</td><td>24 horas</td></tr>
<tr><td>Apartado en compra directa</td><td>30 minutos</td></tr>
<tr><td>Extensión por puja de último momento</td><td>40 segundos</td></tr>
<tr><td>Liberación del pago en envíos sin reclamo</td><td>7 días</td></tr>
</table>

<h2>Cómo comprar en 5 pasos</h2>
<ol>
<li>Crea tu cuenta y verifica tu correo.</li>
<li>Deja el depósito de garantía de $200 si vas a pujar (para compra directa no hace falta).</li>
<li>Puja o toca Comprar ahora.</li>
<li>Paga dentro de la plataforma: tarjeta, Mercado Pago u OXXO.</li>
<li>Recibe el artículo y entrega tu código de 6 dígitos al vendedor; hasta entonces tu dinero queda retenido.</li>
</ol>

<h2>Cómo vender en 5 pasos</h2>
<ol>
<li>Verifica tu identidad con INE (una sola vez).</li>
<li>Sube fotos reales del artículo, de todos los lados.</li>
<li>Elige subasta (1 a 7 días o en vivo) o precio fijo.</li>
<li>Cuando se pague, coordina la entrega desde la app.</li>
<li>Recibe tu dinero al capturar el código del comprador o cuando confirme que llegó bien.</li>
</ol>
"""

FAQ_HTML = FAQ_INTRO + "\n".join(
    f"<h2>{html.escape(q)}</h2>\n<p>{html.escape(a)}</p>" for q, a in FAQ)
FAQ_LD = {"@context": "https://schema.org", "@type": "FAQPage", "mainEntity": [
    {"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": a}} for q, a in FAQ]}

PAGES = [
    ("como-funciona.html", "Cómo funciona Subástalo Aquí · Subastas en línea en Camargo y Delicias",
     "Compra y vende en subasta o a precio fijo en el centro-sur de Chihuahua, con pago protegido hasta que recibes el artículo.", COMO, None),
    ("comisiones.html", "Comisiones · Subástalo Aquí",
     "Publicar es gratis y vender cuesta 0 % de comisión hasta el 31 de marzo de 2027. Después, comisión por tramos de 10 %, 8 % y 6 %.", COMISIONES, None),
    ("preguntas-frecuentes.html", "Preguntas frecuentes · Subástalo Aquí",
     "Cómo pujar, cómo pagar, cuánto cuesta vender, depósito de garantía, reclamos y subastas en vivo en Subástalo Aquí.", FAQ_HTML, FAQ_LD),
]

LLMS = f"""# Subástalo Aquí

> Plataforma local de subastas y ventas en línea para el centro-sur de Chihuahua, México (Camargo, Delicias, Meoqui, Saucillo, Jiménez, La Cruz y San Francisco de Conchos; vendedores también en la ciudad de Chihuahua). El comprador paga dentro de la plataforma y su dinero queda protegido hasta que recibe el artículo.

Datos clave:
- Subastas por tiempo (1 a 7 días), subastas en vivo con video de YouTube y venta a precio fijo.
- Comisión para el vendedor: 0 % hasta el 31 de marzo de 2027 (hasta 30 ventas al mes); después 10 % / 8 % / 6 % por tramos, mínimo $50 MXN. El comprador no paga comisión.
- Pagos: tarjeta, saldo de Mercado Pago, y efectivo en OXXO y tiendas para ganadores de subasta.
- Depósito de garantía de $200 MXN para pujar (reembolsable); compra directa sin depósito.
- Cierre extendido: una puja en los últimos 40 segundos alarga la subasta 40 segundos.
- Vendedores verificados con INE; pago retenido hasta la entrega; reclamos con fotos.
- Contacto: contacto@subastaloaqui.com

## Páginas
- [Cómo funciona]({SITE}/como-funciona.html): proceso de compra y venta, subastas en vivo y seguridad.
- [Comisiones]({SITE}/comisiones.html): tabla de comisiones, ejemplos y Tiendas Oficiales.
- [Preguntas frecuentes]({SITE}/preguntas-frecuentes.html): pagos, depósito, reclamos y reglas.
- [Catálogo]({SITE}/): subastas y artículos activos (aplicación web).
"""

ROBOTS = f"""User-agent: *
Allow: /
Disallow: /adminPanel

Sitemap: {SITE}/sitemap.xml
"""

SITEMAP = """<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
""" + "".join(
    f"  <url><loc>{SITE}/{p}</loc><lastmod>{UPDATED}</lastmod></url>\n"
    for p in ["", "como-funciona.html", "comisiones.html", "preguntas-frecuentes.html"]) + "</urlset>\n"

if __name__ == "__main__":
    for slug, title, desc, body, ld in PAGES:
        (WEB / slug).write_text(page(slug, title, desc, body, ld), encoding="utf-8")
    (WEB / "llms.txt").write_text(LLMS, encoding="utf-8")
    (WEB / "robots.txt").write_text(ROBOTS, encoding="utf-8")
    (WEB / "sitemap.xml").write_text(SITEMAP, encoding="utf-8")
    print("ok")
