# Guía de uso de TrazaCafé

Para técnicos de campo y administradores de una cooperativa, exportadora o beneficio de café o cacao.

## 1. ¿Qué es TrazaCafé?

TrazaCafé registra el camino del café o cacao desde la finca hasta el contenedor de exportación. El reglamento europeo contra la deforestación (**EUDR**) exige demostrar dos cosas:

- de qué fincas viene cada contenedor, con su ubicación;
- que esas fincas no deforestaron después del 31/12/2020.

El camino tiene cinco pasos:

**Productor → Finca → Entrega → Lote → Contenedor**

| Quién | Qué hace en la app |
|---|---|
| **Técnico** | Registra productores, fincas, visitas de verificación, fotos y entregas. Funciona **sin señal**. |
| **Administrador** | Todo lo del técnico, más equipo, cultivos, temporadas, lotes y contenedores. Estas tareas **necesitan señal**. |
| **Comprador** | No usa la app. Escanea el QR del contenedor y ve el origen en una página web. |

Los productores no entran a la app; son registros que lleva el técnico.

## 2. Primeros pasos

### Instalar y entrar
1. Instala el APK que te dio el administrador.
2. Abre **TrazaCafé** y toca **Entrar con Google**.
3. Usa **la misma cuenta de Google** con la que te invitó tu organización. Si sale "Tu cuenta no está autorizada", pide al administrador que te invite (sección 4.1).

### Sin señal y Sincronizar
- **Sin señal:** todo lo que registras se guarda en el celular.
- **Sincronizar:** arriba, en la pantalla de **Productores**, hay un botón con un número: son los registros pendientes de enviar. Cuando tengas señal, tócalo para enviarlos y recibir lo que registró el resto del equipo.
- **Recomendación:** sincroniza al terminar cada día de campo.
- **Lo que necesita señal siempre:** corregir algo que ya se envió, los lotes, los contenedores y la revisión satelital.

### Temporadas
Las entregas y visitas se agrupan por **temporada de cosecha** (por ejemplo, 2026/27). Si sale "No hay temporada de cosecha para hoy", el administrador debe crearla (sección 4.3). Mientras tanto, lo que registres se guarda igual y se asigna solo cuando exista la temporada.

## 3. Para el técnico

### 3.1 Registrar un productor
1. En **Productores**, toca **Nuevo productor**.
2. Escribe el **nombre completo**. La **cédula** y la **comunidad** son opcionales.
   - La cédula se revisa con el formato nicaragüense, por ejemplo `001-010190-0001A`.
   - Se puede escribir sin guiones.
3. Toca **Guardar productor**.

### 3.2 Registrar una finca
1. Abre el productor y toca **Nueva finca**.
2. Escribe el **nombre de la finca** y toma una **foto de la finca**.
3. Revisa el **cultivo**:
   - Si la organización tiene café y cacao, elige con el selector.
   - Si solo tiene uno, aparece fijo.
4. **Marca el lindero:** camina por el borde de la finca y toca **Agregar mi ubicación** en cada esquina. Si te equivocas, toca **Quitar último punto**.

| Tamaño de la finca | Qué marcar |
|---|---|
| **Menos de 4 ha** | Basta **un punto**, idealmente en el centro, y escribir el **área declarada** en hectáreas. |
| **4 ha o más** | El **polígono completo**: al menos 3 puntos, siguiendo el borde. El área la calcula la app. |

5. Toca **Guardar finca**.

**Consejos:**
- **Sin señal** el mapa no carga, pero los puntos se marcan igual con el GPS.
- **El polígono no puede cruzarse** sobre sí mismo. Camina el borde en orden, sin saltar de un lado al otro.

### 3.3 Visita de verificación (una por temporada)
Para que las entregas de una finca puedan exportarse, la finca necesita **una visita de verificación en la temporada**.

1. Abre la finca y toca **Hacer visita de verificación**.
2. Toma **al menos una foto** con **Tomar foto**.
3. Responde **¿Cambió el lindero de la finca?** Si cambió, marca el **nuevo lindero**; el anterior se ve en blanco como guía.
4. Escribe una **nota** si viste algo: tala, quemas, ampliaciones.
5. Toca **Guardar visita**.

La tarjeta de la finca muestra si la visita de la temporada está **pendiente** o **hecha**.

### 3.4 Revisión satelital
TrazaCafé revisa cada finca con mapas satelitales públicos. Usa dos fuentes:
- **JRC 2020** de la Comisión Europea: dónde había bosque en 2020;
- **Hansen/UMD:** dónde se perdió cobertura de árboles cada año.

Cada día revisa sola las fincas que aún no tienen revisión en la temporada. El resultado aparece en la finca:

| Color | Significa | ¿Puede exportar? |
|---|---|---|
| 🟢 Verde | Sin deforestación detectada después de 2020 | Sí |
| 🟡 Amarillo | Posible pérdida pequeña (menos de 0.1 ha): hay que revisar | No, hasta revisarla |
| 🔴 Rojo | Pérdida de bosque después de 2020 (0.1 ha o más) | **No** |

El **administrador** puede pedir la revisión en el momento con **Revisar por satélite**. Necesita señal y que la finca ya esté enviada.

### 3.5 Registrar una entrega
Una entrega es lo que el productor trae al beneficio o centro de acopio.

1. Abre la finca y toca **Entrega**.
2. Escribe los **kilos entregados**, elige el **estado** y revisa la **fecha**. Los estados son:
   - **Café:** uva (café maduro), pergamino u oro (café verde).
   - **Cacao:** en baba (fresco), fermentado o seco.
3. Toca **Guardar entrega**. Sale un resumen en letra grande, **"¿Registrar así?"**. Revísalo bien: es el momento de ver si sobra o falta un cero. Toca **Sí, guardar** o **Revisar**.

**La app avisa si:**
- con esa entrega, la finca superaría lo que razonablemente puede producir en la temporada según su área ("¿No sobra un cero?");
- la fecha tiene más de 30 días;
- la finca **no tiene visita** en la temporada o está en **rojo**. Puedes registrarla igual, pero esa entrega no podrá ir a un lote de exportación hasta que se resuelva.

### 3.6 Fotos
- **Agregar:** toca **Agregar foto** en la finca. Las fotos se suben al sincronizar.
- **Quitar una foto equivocada:** **mantenla presionada** y confirma.

### 3.7 Corregir errores
Todos nos equivocamos: un cero de más, la fecha o el estado equivocado, un nombre mal escrito. Para eso hay correcciones.

**Dónde se corrige cada cosa:**

| Qué | Cómo |
|---|---|
| **Entrega** (kg, estado, fecha) | Toca la entrega en la finca → **Corregir entrega**, o **Anular entrega** si no debió existir |
| **Productor** (nombre, cédula, comunidad) | En el productor, el lápiz de arriba → **Corregir productor** |
| **Finca** (nombre; área declarada si es de un punto) | En la finca, el lápiz **Corregir nombre o área** |
| **Visita** (nota, fecha) | En la tarjeta de verificación, el lápiz **Corregir visita**; ahí también está **Anular visita** |
| **Foto** | Mantenla presionada → quitar |
| **Cultivo de la finca** | **Cambiar cultivo**, solo si todavía no tiene entregas |

**Reglas:**
- **Quién corrige:** cada técnico corrige **lo que él registró**; el administrador corrige todo.
- **Motivo obligatorio** al cambiar **kilos, áreas o fechas** y al **anular**, por ejemplo "un cero de más". Queda en el historial con tu nombre y la fecha.
- **Anular no borra:** la entrega o visita anulada queda en el historial, pero deja de contar.
- **Con o sin señal:**
  - si el dato **todavía no se envió**, se corrige en el celular, sin señal;
  - si **ya se envió**, la corrección necesita señal.
- **Cuándo ya no se puede:** si la entrega ya está **en un lote** o el dato ya está **registrado en la blockchain**. La app explica por qué. En ese caso, avisa al administrador; por ejemplo, puede deshacer el lote si todavía no está firmado.

## 4. Para el administrador

Las opciones de administrador están en el menú **⋮**, arriba a la derecha de **Productores**.

### 4.1 Equipo
- **Invitar:** **⋮ → Equipo → Invitar**. Escribe el **correo de Google** de la persona y elige **Técnico** o **Administrador**. La persona instala la app y entra con **Entrar con Google** usando ese correo.
- **Quitar acceso:** en la lista del equipo, toca el ícono **Quitar acceso** junto a la persona. Su sesión se cierra al instante y lo que registró se conserva.

### 4.2 Cultivos
En **⋮ → Cultivos**, marca los cultivos que acopia la organización (café, cacao). No se puede quitar un cultivo que ya tiene fincas.

### 4.3 Temporadas
En **⋮ → Temporadas → Temporada** se crea una temporada con:
- un **nombre**, por ejemplo 2026/27;
- una fecha de **inicio** y una de **fin**;
- el **cultivo**: "Todos los cultivos" o solo uno, por ejemplo una cosecha de cacao con fechas propias.

Reglas:
- **Traslapes:** dos temporadas del mismo cultivo no pueden traslaparse.
- **Duración:** si una temporada dura más de 18 meses, la app avisa (puede ser un año mal escrito).
- **Corregir:** toca la temporada. Se puede cambiar el nombre siempre; las fechas, o eliminarla, solo mientras no tenga lotes. Las entregas y visitas se reacomodan solas.

### 4.4 Lotes
Un **lote** junta entregas **de un mismo cultivo y temporada**, como sale del beneficio, por ejemplo café pergamino.

1. **⋮ → Lotes → Nuevo lote**.
2. Elige la **temporada** y el **estado** en que queda el lote.
3. Marca las **entregas disponibles**. Abajo aparecen las que **no pueden ir** y por qué:
   - finca en **rojo**;
   - finca **sin visita** en esa temporada;
   - entrega de otro cultivo o de otra temporada;
   - entrega que ya está en otro lote.
4. Escribe el **código del lote**, el **peso en la báscula** y, si quieres, el **beneficio** y el **proceso**.
5. Toca **Crear lote**.

**Avisos (no impiden crear el lote):**
- **Volumen:** el lote pesa más de un 10 % por encima de lo que rinden sus entregas. Por ejemplo, 500 kg de uva rinden unos 100 kg de pergamino.
- **Rendimiento:** una finca entregó más de lo que puede producir por hectárea.
- **Satélite:** alguna finca no está en verde.

**Corregir o deshacer:**
- **Corregir:** peso, código, beneficio y proceso, con motivo si cambia el peso.
- **Deshacer lote:** sus entregas quedan libres.
- **Límite:** las dos cosas solo mientras el lote no esté en un contenedor ni firmado en la blockchain.

### 4.5 Contenedores y paquete EUDR
Un **contenedor** junta lotes **de un mismo cultivo** para un comprador.

1. **⋮ → Contenedores → Contenedor**.
2. Elige los **lotes libres** y escribe el **código interno**, el **comprador**, el **destino** y, si ya lo tienes, el **número de contenedor**.
3. Toca **Crear contenedor**.

**Paquete EUDR**, en la tarjeta del contenedor:
- **PDF:** resumen para el comprador, con fincas de origen, áreas, chequeos y visitas.
- **GeoJSON (TRACES):** la ubicación de cada finca, para subir a **TRACES**, el sistema de la Unión Europea donde se presenta la **declaración de diligencia debida (DDS)**.
  - La app pregunta si incluir los nombres de los productores. TRACES no los exige y son datos personales; lo normal es **Sin nombres**.

**Pasos hasta la exportación:**

1. **Editar datos:** completa el **número de contenedor** con formato ISO, por ejemplo `MSCU1234565`. La app revisa su dígito de control. Agrega también la **fecha de embarque**.
2. **Cerrar.** Para poder cerrar, el contenedor necesita:
   - el número de contenedor;
   - **todas sus fincas en verde**.

   Si falta algo, la app dice qué. Al cerrarlo ya no se cambian sus lotes ni sus datos.
3. **Presentar la DDS en TRACES** con el GeoJSON. Lo hace el exportador o su agente aduanal, fuera de la app.
4. **Anotar DDS:** escribe la **referencia** que devolvió TRACES.
5. **Firma en la blockchain:** en la hora siguiente, TrazaCafé registra el contenedor en la blockchain. La tarjeta muestra **Registrado en la blockchain ✓** y desde ese momento **ni la DDS se puede cambiar**.
6. **QR del verificador:**
   - **Copiar enlace**, o **Compartir QR** como imagen, con el número de contenedor debajo;
   - sirve para la etiqueta del contenedor o para mandarlo al comprador por WhatsApp o correo.

## 5. Qué ve el comprador

Al escanear el QR se abre una página web, sin instalar nada ni crear cuenta.

**Qué muestra:**
- el contenedor, el destino, los kg y la DDS;
- un sello **Verificado en la blockchain**. La página lo comprueba por su cuenta, leyendo la blockchain directamente: quién lo firmó, que no está revocado y que los datos coinciden;
- un mapa con la **ubicación aproximada** (~1 km) de las fincas;
- los lotes, y cada finca como "Finca 1", "Finca 2"…, con su área, revisión satelital, visita y entregas;
- enlaces a cada registro en la blockchain.

**Qué no muestra:** nombres de productores ni de fincas, cédulas, el nombre del comprador ni las coordenadas exactas.

## 6. Problemas comunes

| Situación | Qué hacer |
|---|---|
| "Tu cuenta no está autorizada" | Entra con el correo invitado, o pide al administrador que te invite. |
| El número de **Sincronizar** no baja | Busca señal y toca Sincronizar. Si da error, anota el mensaje y avísale al administrador. |
| "Necesitas señal" al corregir | El dato ya se envió. Corrígelo cuando tengas señal. |
| "No se puede corregir" | La entrega ya está en un lote o firmada en la blockchain. Avisa al administrador. |
| Una entrega "no puede ir en un lote" | Revisa el motivo: falta la visita de la temporada, la finca está en rojo, o es de otra temporada o cultivo. |
| El contenedor "todavía no se puede cerrar" | Falta el número de contenedor o hay fincas sin chequeo verde. La app las nombra. |
| El mapa no carga | Sin señal no hay mapa, pero el GPS sigue marcando puntos con **Agregar mi ubicación**. |
| Celular nuevo o reinstalación | Entra con la misma cuenta y toca **Sincronizar**: se descargan los datos de la organización. Lo que **no** se había sincronizado en el celular anterior se pierde. |

## 7. Palabras que aparecen en la app

| Palabra | Significa |
|---|---|
| **EUDR** | Reglamento de la Unión Europea contra la deforestación: el café y el cacao que entran a Europa deben venir de tierras sin deforestación después del 31/12/2020. |
| **Lindero** | Borde de la finca. Puede ser un punto (menos de 4 ha) o un polígono. |
| **Área declarada** | Hectáreas que dice el productor, en fincas de un solo punto. |
| **Temporada** | Período de cosecha que agrupa entregas y visitas. |
| **Lote** | Entregas juntas en el beneficio, de un cultivo y una temporada. |
| **DDS** | Declaración de diligencia debida: el documento que se presenta en **TRACES** antes de exportar a la Unión Europea. |
| **TRACES** | Sistema de la Comisión Europea donde se presentan las DDS. |
| **Blockchain / attestation** | Registro público que nadie puede alterar. TrazaCafé firma ahí cada finca, visita, entrega, lote y contenedor, para que el comprador pueda comprobarlo. Hoy en red de pruebas (OP Sepolia). |
| **QR del verificador** | Código que lleva a la página pública del contenedor. |
