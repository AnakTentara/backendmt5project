import { clsx } from 'clsx';
import { useState } from 'react';
import { Badge } from '@/components/Badge';
import { Button } from '@/components/Button';
import { Panel } from '@/components/Panel';
import { BRUTE_CONFIG_FIELDS, type ConfigFieldSpec } from '@/domain/constants';
import { configUpdateSchema } from '@/api/contracts';
import { useUpdateConfig } from '@/hooks/useTradeMachine';

/**
 * Runtime config form.
 *
 * HONEST ABOUT A BACKEND LIMITATION
 * ---------------------------------
 * Flask accepts all five keys, but `ParseConfigChange()` in HTTPReceiver.mqh
 * only reads `max_orders`. The other four are validated, acknowledged with
 * `success: true`, and then silently discarded by MT5.
 *
 * The form therefore marks those fields as not-yet-applied rather than letting
 * a green success toast imply the EA changed behaviour. Reporting a config
 * change that did not happen is worse than reporting no change at all.
 */
export function ConfigForm() {
  const updateConfig = useUpdateConfig();
  const [values, setValues] = useState<Record<string, string>>({});
  const [validationError, setValidationError] = useState<string | null>(null);

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault();
    setValidationError(null);

    // Only dirty fields are sent; the API treats absent keys as "leave alone".
    const payload: Record<string, number> = {};
    for (const [key, raw] of Object.entries(values)) {
      if (raw.trim() === '') continue;
      const parsed = Number(raw);
      if (!Number.isFinite(parsed)) {
        setValidationError(`${key} is not a valid number`);
        return;
      }
      payload[key] = parsed;
    }

    // Validated client-side against the documented bounds so an out-of-range
    // value becomes an inline message instead of a server rejection.
    const result = configUpdateSchema.safeParse(payload);
    if (!result.success) {
      const firstIssue = result.error.issues[0];
      setValidationError(
        firstIssue
          ? `${firstIssue.path.join('.') || 'form'}: ${firstIssue.message}`
          : 'Invalid configuration',
      );
      return;
    }

    // `result.data` is already `ConfigUpdate`; the schema's inferred type is exact.
    updateConfig.mutate(result.data, {
      onSuccess: () => setValues({}),
    });
  };

  const hasChanges = Object.values(values).some((value) => value.trim() !== '');

  return (
    <Panel
      title="Runtime configuration"
      subtitle="POST /api/config/set"
      action={<Badge tone="neutral">{BRUTE_CONFIG_FIELDS.length} fields</Badge>}
    >
      <form onSubmit={handleSubmit} className="space-y-4">
        <div className="grid gap-4 sm:grid-cols-2">
          {BRUTE_CONFIG_FIELDS.map((field) => (
            <ConfigField
              key={field.key}
              spec={field}
              value={values[field.key] ?? ''}
              onChange={(next) =>
                setValues((current) => ({ ...current, [field.key]: next }))
              }
            />
          ))}
        </div>

        <div className="rounded-md border border-status-warning/30 bg-status-warningSoft/30 px-3 py-2.5">
          <p className="text-caption text-content-secondary">
            Only <span className="font-mono">max_orders_per_min</span> currently
            reaches the EA. The remaining fields are accepted by the bridge but
            not yet parsed by <span className="font-mono">HTTPReceiver.mqh</span>,
            so they will not change engine behaviour.
          </p>
        </div>

        {validationError !== null && (
          <p className="text-label text-status-danger" role="alert">
            {validationError}
          </p>
        )}

        {updateConfig.error && (
          <p className="text-label text-status-danger" role="alert">
            {updateConfig.error.message}
          </p>
        )}

        {updateConfig.isSuccess && !hasChanges && (
          <p className="text-label text-status-success" role="status">
            Configuration command queued. MT5 applies supported fields on its next poll.
          </p>
        )}

        <div className="flex justify-end gap-2 border-t border-surface-border pt-4">
          <Button
            variant="ghost"
            onClick={() => {
              setValues({});
              setValidationError(null);
            }}
            disabled={!hasChanges}
          >
            Reset
          </Button>
          <Button
            type="submit"
            variant="primary"
            loading={updateConfig.isPending}
            disabled={!hasChanges}
          >
            Apply changes
          </Button>
        </div>
      </form>
    </Panel>
  );
}

function ConfigField({
  spec,
  value,
  onChange,
}: {
  readonly spec: ConfigFieldSpec;
  readonly value: string;
  readonly onChange: (next: string) => void;
}) {
  const inputId = `config-${spec.key}`;

  return (
    <div className="min-w-0">
      <label htmlFor={inputId} className="flex items-center gap-2">
        <span className="truncate text-label font-medium text-content-secondary">
          {spec.label}
        </span>
        {!spec.appliedByBackend && (
          <Badge tone="warning" size="sm">
            NOT APPLIED
          </Badge>
        )}
      </label>

      <div className="mt-1.5 flex items-center gap-2">
        <input
          id={inputId}
          type="number"
          min={spec.min}
          max={spec.max}
          step={spec.step}
          value={value}
          placeholder={`${spec.min} – ${spec.max}`}
          onChange={(event) => onChange(event.target.value)}
          aria-describedby={`${inputId}-help`}
          className={clsx(
            'tabular min-w-0 flex-1 rounded-md border bg-surface-overlay px-3 py-2',
            'font-mono text-body text-content-primary placeholder:text-content-disabled',
            'focus:outline-none',
            spec.appliedByBackend
              ? 'border-surface-borderStrong focus:border-accent-base'
              : 'border-status-warning/30 focus:border-status-warning',
          )}
        />
        <span className="shrink-0 text-caption text-content-muted">{spec.unit}</span>
      </div>

      <p id={`${inputId}-help`} className="mt-1 text-caption text-content-muted">
        {spec.help}
      </p>
    </div>
  );
}
