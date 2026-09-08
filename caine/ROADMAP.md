# CAINE en arm64 — Roadmap (v0.2)

🇬🇧 [English version](ROADMAP.en.md)

## Estado actual

Sin pruebas realizadas. A diferencia de REMnux (Salt states vía `remnux/salt-states`) y SIFT (Salt states vía `teamdfir/sift-saltstack`, instalados con `cast`), **CAINE no tiene un mecanismo de conversión de paquetes propio conocido**: es una distro Live/instalable pensada para arrancar desde ISO/USB con su propio conjunto de herramientas preinstaladas, no un "addon" que se aplique sobre una base Debian existente.

Esto significa que el enfoque usado con REMnux y SIFT (clonar el repo de states, aplicar sobre Debian/Asahi, excluir lo que falla) probablemente **no aplica directamente** a CAINE.

## Plan para v0.2

1. **Inventariar las herramientas de CAINE.** Extraer la lista completa de paquetes/herramientas que trae la ISO oficial (vía `dpkg -l` sobre una instalación de referencia, o revisando su repo/build scripts si son públicos).
2. **Clasificar cada herramienta** en:
   - Paquete apt estándar de Debian/Ubuntu → probablemente portable sin cambios.
   - Script/herramienta propia de CAINE (Python/Bash) → portable revisando dependencias.
   - Binario compilado solo para amd64 sin build arm64 conocido → candidato a descartar o sustituir.
3. **Priorizar** las herramientas forenses "núcleo" (adquisición de imágenes, análisis de sistemas de archivos, timeline) frente a utilidades secundarias, siguiendo el mismo criterio de riesgo usado en REMnux (ruidoso/silencioso/explícito).
4. **Probar en VM arm64** (mismo entorno UTM + Ubuntu Desktop 24.04 usado para REMnux/SIFT) las herramientas candidatas, con snapshot antes de cada prueba.
5. Documentar resultados en este mismo fichero / en un `FINDINGS.md` análogo al de REMnux y SIFT cuando haya datos reales.

## Nota

Esta sección se actualizará según se investigue en próximas versiones. En v0.1 se deja intencionadamente como marcador de posición para no mezclar hallazgos reales (SIFT, REMnux) con contenido sin validar.
