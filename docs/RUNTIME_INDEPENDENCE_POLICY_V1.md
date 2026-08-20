# RUNTIME-INDEPENDENCE-1.0

## Regla soberana transversal

Vercel no es una dependencia obligatoria de ningún agente del sistema. Es, cuando exista y esté físicamente desplegado, un adaptador HTTP opcional y reemplazable.

Un fallo de Vercel, ausencia de proyecto visible, límite de builds, fallo de deployment o indisponibilidad del proveedor **no puede cambiar por sí solo el estado global de una corrida ni impedir la ejecución del agente** cuando la ruta canónica de ejecución del agente sigue disponible.

Solo una operación solicitada explícitamente como operación de deployment/HTTP sobre Vercel puede quedar bloqueada por Vercel. Ese bloqueo se limita a esa operación y no se propaga al razonamiento, investigación, persistencia, auditoría, Drive, Supabase ni al resto del proceso.

## Política física

`POLICY_VERSION = RUNTIME-INDEPENDENCE-1.0`

`VERCEL_ROLE = OPTIONAL_HTTP_ADAPTER_NON_BLOCKING`

`VERCEL_REQUIRED = FALSE`

`VERCEL_FAILURE_BLOCKS_EXECUTION = FALSE`

`HTTP_RUNTIME_REQUIRED = FALSE` salvo que una futura autoridad soberana declare explícitamente una operación HTTP específica como requisito; incluso en ese caso no puede convertir a Vercel en proveedor obligatorio.

El estado de ejecución de cada agente se deriva de su autoridad vigente, sus hard gates del dominio y la disponibilidad de su ruta canónica; nunca del estado de Vercel por sí solo.

## Rutas canónicas actuales

- `@NRFImetrica`: Supabase + connected Kernel; runtime HTTP preferido y verificado: Supabase Edge Function `nrfimetrica-research` con JWT. Vercel eliminado como dependencia.
- `@NRFiPrensa`: connected agent/kernel + persistencia Supabase. Vercel opcional y no requerido.
- `@DepuracionMLB`: connected agent/kernel + persistencia Supabase. Su estado `DISABLED` se conserva por validación propia V0.7 y no tiene relación con Vercel.
- `@investigacionNRFI`: connected kernel + persistencia Supabase. Las rutas `/api/investigacion_nrfi*` son interfaces HTTP de compatibilidad, no requisito de ejecución.
- `@ianalista`: autoridad Drive + ejecución conectada según su sistema vigente. No se fabrica un runtime dedicado inexistente. Vercel no es requisito.
- `@iainvestigadora`: connected kernel + persistencia compartida Supabase. La ruta HTTP histórica es opcional.
- `@iaindependiente`: connected kernel + persistencia compartida Supabase. Vercel no es requisito.
- `@AuditorSistema`: auditor conectado + namespace de auditoría Supabase. Vercel no es requisito.

## Auditoría

`@AuditorSistema` debe marcar como incumplimiento material cualquier RUN que se detenga o se declare bloqueado exclusivamente por Vercel cuando exista una ruta canónica válida. El hallazgo se clasifica como `EXECUTED_INCORRECTLY / RUNTIME_PROVIDER_COUPLING` y debe demostrar el estado del proveedor y la disponibilidad de la ruta canónica en el tiempo del RUN.

No se considera fallo que una operación explícitamente Vercel-specific no pueda ejecutarse cuando Vercel está indisponible; lo incorrecto es propagar ese fallo al agente completo.

## Compatibilidad

`vercel.json` y los handlers bajo `api/` pueden permanecer en el repositorio como adaptadores opcionales. Su presencia no establece autoridad ni dependencia. El runtime puede migrarse o coexistir con Supabase Edge Functions sin cambiar la lógica deportiva ni el contrato de cada agente.