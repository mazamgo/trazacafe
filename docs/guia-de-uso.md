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
- **Celular de otra organización:** cada celular guarda los datos de una sola organización. Si entras en un celular que usó otra organización, la app borra sus datos (si ya estaban enviados) y descarga los de la tuya.
- **Lo que necesita señal siempre:** corregir algo que ya se envió, los lotes, los contenedores y la revisión satelital.

### Tema claro u oscuro
En **⋮ → Tema** elige **Automático** (el que tenga el celular), **Claro** u **Oscuro**. El oscuro descansa la vista de noche y gasta menos batería en muchas pantallas. El celular recuerda la elección.

### Temporadas
Las entregas y visitas se agrupan por **temporada de cosecha** (por ejemplo, 2026/27). Si sale "No hay temporada de cosecha para hoy", el administrador debe crearla (sección 4.3). Mientras tanto, lo que registres se guarda igual y se asigna solo cuando exista la temporada.

### Eliminar tu cuenta
En **⋮ → Privacidad y datos → Eliminar mi cuenta**. La app primero envía lo pendiente; si no hay señal, avisa y puedes esperar o eliminarla de todos modos (lo pendiente se pierde). Después se borran tu cuenta y los datos del celular, y la app vuelve a la pantalla de entrar.

- Lo que registraste (productores, fincas, entregas) es de la organización y se queda con ella, sin tu nombre ni tu correo.
- Si eres el **único administrador**, primero nombra a otro en **Equipo** o elimina la organización.
- También se puede hacer sin la app, desde la página **https://trazacafe-dev.web.app/eliminar-datos** (entrando con Google).

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
4. **Ubica el terreno en el mapa.** El mapa abre cerca de la finca:
   - si el productor ya tiene otra finca, en ella;
   - si no, en las fincas de su **comunidad** o en la comunidad misma;
   - si no, donde quedó el mapa la última vez.

   Para llegar más rápido:
   - **Ir a mi ubicación** (botón redondo del mapa): lleva el mapa a donde estás, sin marcar ningún punto.
   - **Lupa** (arriba): escribe una comunidad, comarca o pueblo, el nombre de otra finca o el de un productor. Funciona **sin señal**.
   - **Coordenadas:** en la lupa también puedes pegar coordenadas (`13.0910, -86.0023` o `13°05'27"N 86°00'08"W`) o la **ubicación que te mandó el productor por WhatsApp** (el enlace de Google Maps). Los enlaces cortos (`maps.app.goo.gl/…`) necesitan señal.

   El lugar elegido queda marcado con un **pin azul**, que no es un punto del lindero. Las fincas ya registradas se ven en **gris** con su nombre: sirven para ubicarte y para no registrar dos veces el mismo terreno.
5. **Marca el lindero:** camina por el borde de la finca y toca **Agregar mi ubicación** en cada esquina. Si te equivocas, toca **Quitar último punto**.

| Tamaño de la finca | Qué marcar |
|---|---|
| **Menos de 4 ha** | Basta **un punto**, idealmente en el centro, y escribir el **área declarada** en hectáreas. |
| **4 ha o más** | El **polígono completo**: al menos 3 puntos, siguiendo el borde. El área la calcula la app. |

6. Toca **Guardar finca**.

**Consejos:**
- **Sin señal** el mapa de Google no carga, pero los puntos se marcan igual con el GPS. La lupa y **Ir a mi ubicación** también funcionan.
- **Mapa sin señal:** antes de salir, con Wi-Fi, descarga el mapa satelital de tu zona en **⋮ → Mapas sin señal**. En la montaña, sin señal, "Nueva finca" lo muestra en lugar del de Google.
  - Es de menor detalle (10 m por píxel, imágenes Sentinel-2 de la época seca): se ven bosque, claros, caminos y ríos, no cada mata. Sirve para ubicarte; el lindero se sigue marcando caminando con el GPS.
  - Si miraste la zona en el mapa de Google con señal ese mismo día, también se sigue viendo sin señal hasta el día siguiente.
- **Con señal, desde la oficina**, puedes buscar la comunidad y revisar el terreno en el satélite antes de ir. Los puntos se marcan en campo.
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

Si está activado, también consulta las **alertas recientes de Global Forest Watch**, pero solo en fincas que tenían bosque en 2020. Las alertas avisan antes que Hansen, aunque no siempre son deforestación (puede ser una poda de sombra o una renovación del cafetal). Por eso una alerta deja la finca en amarillo, nunca en rojo.

Cada día revisa sola las fincas que aún no tienen revisión en la temporada. El resultado aparece en la finca:

| Color | Significa | ¿Puede exportar? |
|---|---|---|
| 🟢 Verde | Sin deforestación detectada después de 2020 | Sí |
| 🟡 Amarillo | Posible pérdida pequeña (menos de 0.1 ha) o alertas recientes: hay que revisar | No, hasta revisarla |
| 🔴 Rojo | Pérdida de bosque confirmada después de 2020 (0.1 ha o más) | **No** |

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
- **Plazo de 7 días:** una entrega o visita enviada se puede corregir durante **7 días** después de sincronizarla. Pasado ese plazo se registra en la blockchain, con su fecha real. Si antes entra en un lote, se registra en ese momento.
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

**QR del lote (saco):** cuando el lote ya está firmado en la blockchain (**Registrado en la blockchain ✓**), su tarjeta tiene el botón **QR del verificador**, igual que los contenedores (sección 4.5). Sirve para etiquetar los sacos: quien lo escanea ve ese lote, sus entregas y sus fincas de origen.

### 4.5 Contenedores y paquete EUDR
Un **contenedor** junta lotes **de un mismo cultivo** para un comprador.

1. **⋮ → Contenedores → Contenedor**.
2. Elige los **lotes libres** y escribe el **código interno**, el **comprador**, el **destino** y, si ya lo tienes, el **número de contenedor**.
3. Toca **Crear contenedor**.

**Paquete EUDR**, en la tarjeta del contenedor:
- **PDF:** resumen para el comprador, con fincas de origen, áreas, chequeos y visitas. Con el contenedor **abierto** es un **borrador**, para revisarlo con el comprador antes de cerrar.
- **GeoJSON (TRACES):** la ubicación de cada finca de origen. Se manda al **importador** en la Unión Europea, que lo sube a **TRACES** con su **declaración de diligencia debida (DDS)**.
  - **Se descarga solo con el contenedor cerrado**, es decir, con todas sus fincas en verde. Mientras está abierto, el botón está apagado.
  - La app pregunta si incluir los nombres de los productores. TRACES no los exige y son datos personales; lo normal es **Sin nombres**.

**Pasos hasta la exportación:**

1. **Editar datos:** completa el **número de contenedor** con formato ISO, por ejemplo `MSCU1234566`. La app revisa su dígito de control. Agrega también la **fecha de embarque**.
2. **Cerrar.** Para poder cerrar, el contenedor necesita:
   - el número de contenedor;
   - **todas sus fincas en verde**.

   Si falta algo, la app dice qué. Al cerrarlo ya no se cambian sus lotes ni sus datos, y se activa el **GeoJSON (TRACES)**. Cada contenedor cerrado cuenta para el plan de tu organización con GoProduction.
3. **Enviar el paquete al importador:**
   - manda el **GeoJSON** y el **PDF** al comprador o importador en la Unión Europea, con los botones de la tarjeta (correo, WhatsApp);
   - con ellos, el importador presenta la **DDS** en **TRACES**, desde su propia cuenta y antes de que el café entre a la UE;
   - la aduana europea le pide la referencia de esa DDS al despachar la carga.

   La DDS la presenta el **"operador"**: la empresa que pone el café o cacao por primera vez en el mercado de la UE. Normalmente es el importador. Si tu empresa tiene sede en la UE y vende ella misma allá, entonces la presenta tu empresa.
4. **Anotar DDS:** el importador te devuelve el **número de referencia** de su DDS; TRACES también le da un número de verificación. Escribe la referencia en **Anotar DDS**. Se puede anotar con el contenedor ya cerrado, mientras no esté firmado.
5. **Firma en la blockchain:** en la hora siguiente, TrazaCafé registra el contenedor en la blockchain. La tarjeta muestra **Registrado en la blockchain ✓** y desde ese momento **ni la DDS se puede cambiar**.
6. **QR del verificador:**
   - **Copiar enlace**, o **Compartir QR** como imagen, con el número de contenedor debajo;
   - sirve para la etiqueta del contenedor o para mandarlo al comprador por WhatsApp o correo;
   - el QR va en blanco y negro aunque el celular esté en tema oscuro, para que cualquier cámara lo lea.

### 4.6 Eliminación de datos (Privacidad y datos)
Un productor puede pedir que se borren sus datos (Ley 787). Lo pide en la página **https://trazacafe-dev.web.app/eliminar-datos** o en persona; la cooperativa confirma que es él y lo elimina.

- **Solicitudes de la página web:** aparece un aviso en **Productores** y en **⋮ → Privacidad y datos → Solicitudes de eliminación**. Cada solicitud muestra lo que escribió el productor (nombre, cédula, comunidad y un teléfono o correo).
  - **Buscar y eliminar:** busca al productor por nombre o cédula, elígelo y confirma.
  - **Rechazar:** con el motivo, por ejemplo "no es productor nuestro". Avísale antes al contacto que dejó: al cerrar la solicitud se borran sus datos.
  - Respóndelas en menos de 30 días. Si pasan 15 días sin respuesta, GoProduction te va a escribir.
- **En persona:** abre al productor y toca **⋮ → Eliminar datos del productor** (necesita señal).
- **Qué pasa:**
  - se borran nombre, cédula, comunidad, la foto del consentimiento, las fotos de sus fincas y visitas, y las fincas sin entregas en lotes ni firmadas;
  - si alguna finca tiene entregas en un lote o un contenedor, el EUDR obliga a guardarla **5 años** desde la exportación: queda como **"Productor eliminado"** y **"Finca eliminada · xxxx"**, sin datos personales, y se borra sola al vencer el plazo;
  - no se puede deshacer.
- **Eliminar la organización:** **⋮ → Privacidad y datos → Eliminar la organización**. Se ejecuta a los **30 días**; hasta entonces todos ven un aviso con la fecha y el administrador puede **Cancelar**. Descarga antes lo que necesites (paquetes EUDR, PDF). Ese día se borran el equipo, los productores, las fincas y las fotos, salvo lo que el EUDR obliga a guardar, que queda anónimo 5 años.

## 5. Qué ve el comprador

Al escanear el QR se abre una página web, sin instalar nada ni crear cuenta. Puede ser el QR de un **contenedor** o de un **lote** (saco).

- **Idioma:** sale en **español** si el navegador está en español y en **inglés** para los demás. Arriba se puede cambiar con el botón **English / Español**.
- **Tema:** el ícono de arriba elige **Automático**, **Claro** u **Oscuro**.
- El navegador recuerda las dos elecciones.

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
| Sin señal el mapa se ve gris | Descarga el mapa de tu zona con Wi-Fi en **⋮ → Mapas sin señal**. Si tu zona no está en la lista, pídeselo al administrador. |
| El mapa abre lejos de la finca | Toca **Ir a mi ubicación**, o busca la comunidad con la **lupa**. Si la comunidad no aparece, prueba con una cercana o con el municipio. |
| "Eres el único administrador" al eliminar tu cuenta | Invita a otro administrador en **Equipo** (o elimina la organización) y vuelve a intentarlo. |
| Un productor aparece como "Productor eliminado" | Pidió que borraran sus datos. Sus fincas con entregas exportadas se guardan sin datos personales por el EUDR; no se pueden editar. |
| Celular nuevo o reinstalación | Entra con la misma cuenta y toca **Sincronizar**: se descargan los datos de la organización. Lo que **no** se había sincronizado en el celular anterior se pierde. |
| "Datos de otra organización" al entrar | El celular tiene registros **sin enviar** de otra organización (un celular prestado o heredado). Lo mejor: toca **Cerrar sesión** y que la persona anterior entre con su cuenta y toque **Sincronizar** con señal. Después entras tú y el celular se limpia solo. Si esos datos ya no importan, **Borrar esos datos y continuar** los borra para siempre. |

## 7. Palabras que aparecen en la app

| Palabra | Significa |
|---|---|
| **EUDR** | Reglamento de la Unión Europea contra la deforestación: el café y el cacao que entran a Europa deben venir de tierras sin deforestación después del 31/12/2020. |
| **Lindero** | Borde de la finca. Puede ser un punto (menos de 4 ha) o un polígono. |
| **Área declarada** | Hectáreas que dice el productor, en fincas de un solo punto. |
| **Temporada** | Período de cosecha que agrupa entregas y visitas. |
| **Lote** | Entregas juntas en el beneficio, de un cultivo y una temporada. |
| **DDS** | Declaración de diligencia debida: la presenta en **TRACES** el importador (el "operador") antes de poner el café o cacao en el mercado de la Unión Europea. Lleva la ubicación de las fincas de origen. |
| **TRACES** | Sistema de la Comisión Europea donde se presentan las DDS. |
| **Anonimizar** | Quitar los datos personales (nombre, cédula, fotos) y dejar solo lo que el EUDR obliga a guardar, sin que se sepa de quién es. |
| **Blockchain / attestation** | Registro público que nadie puede alterar. TrazaCafé firma ahí cada finca, visita, entrega, lote y contenedor, para que el comprador pueda comprobarlo. Hoy en red de pruebas (OP Sepolia). |
| **QR del verificador** | Código que lleva a la página pública del contenedor. |
