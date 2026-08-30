import { useCallback, useEffect, useRef, useState } from 'react';
import { Badge } from '@/components/Badge';
import { Button } from '@/components/Button';
import { useEmergencyStop } from '@/hooks/useTradeMachine';

/**
 * Emergency stop control.
 *
 * WHY THE FRICTION IS DELIBERATE
 * ------------------------------
 * `POST /api/emergency/stop` closes ALL positions at market, including regular
 * non-Brute trades. Dashboard_API.md is explicit: "DO NOT USE DURING LIVE
 * TRADING UNLESS EMERGENCY!" It is also irreversible — once positions are
 * closed at market there is no undo, and on VOL_80 a 100-lot position can slip
 * over $1,000 on exit.
 *
 * So a single click cannot trigger it. The gate is:
 *   1. Click opens a modal, it does not fire the request.
 *   2. The consequence is stated in plain language, not a generic "Are you sure?".
 *   3. The confirm button is disabled for 2 seconds, defeating double-click
 *      muscle memory and reflexive Enter presses.
 *   4. Escape and backdrop clicks cancel; nothing but the explicit button fires.
 *
 * This is the one place in the app where slowing the user down is the feature.
 */

const CONFIRM_DELAY_MS = 2_000;

export function EmergencyStopButton() {
  const [isModalOpen, setModalOpen] = useState(false);
  const emergencyStop = useEmergencyStop();

  const openModal = useCallback(() => setModalOpen(true), []);
  const closeModal = useCallback(() => setModalOpen(false), []);

  const handleConfirm = useCallback(() => {
    emergencyStop.mutate(undefined, {
      onSettled: () => setModalOpen(false),
    });
  }, [emergencyStop]);

  return (
    <>
      <Button
        variant="critical"
        size="sm"
        onClick={openModal}
        loading={emergencyStop.isPending}
        icon={<span aria-hidden="true">■</span>}
      >
        Emergency Stop
      </Button>

      {isModalOpen && (
        <ConfirmationModal
          onCancel={closeModal}
          onConfirm={handleConfirm}
          isSubmitting={emergencyStop.isPending}
        />
      )}
    </>
  );
}

function ConfirmationModal({
  onCancel,
  onConfirm,
  isSubmitting,
}: {
  readonly onCancel: () => void;
  readonly onConfirm: () => void;
  readonly isSubmitting: boolean;
}) {
  const [secondsRemaining, setSecondsRemaining] = useState(CONFIRM_DELAY_MS / 1000);
  const cancelButtonRef = useRef<HTMLButtonElement>(null);

  // Countdown gate. Prevents a double-click on the trigger from landing on the
  // confirm button that appears underneath it.
  useEffect(() => {
    if (secondsRemaining <= 0) return undefined;

    const timerId = window.setTimeout(() => {
      setSecondsRemaining((current) => current - 1);
    }, 1_000);

    return () => window.clearTimeout(timerId);
  }, [secondsRemaining]);

  // Escape cancels. Focus moves to Cancel, not Confirm, so a stray Enter is safe.
  useEffect(() => {
    cancelButtonRef.current?.focus();

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onCancel();
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [onCancel]);

  const isArmed = secondsRemaining <= 0;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="emergency-stop-title"
      onClick={(event) => {
        // Backdrop click cancels, but only when the backdrop itself is hit.
        if (event.target === event.currentTarget) onCancel();
      }}
    >
      <div className="w-full max-w-md rounded-lg border border-status-critical/50 bg-surface-raised shadow-lg">
        <div className="flex items-center gap-2.5 border-b border-surface-border px-5 py-4">
          <Badge tone="critical" dot pulse>
            CRITICAL
          </Badge>
          <h2
            id="emergency-stop-title"
            className="text-bodyLg font-semibold text-content-primary"
          >
            Close all positions?
          </h2>
        </div>

        <div className="space-y-3 px-5 py-4">
          <p className="text-body text-content-secondary">
            This closes <strong className="text-content-primary">every open position</strong> at
            market price — including regular trades, not only Brute Mode orders.
          </p>

          <ul className="space-y-1.5 rounded-md bg-status-criticalSoft/40 px-3 py-2.5 text-label text-content-secondary">
            <li>• The action cannot be undone.</li>
            <li>• Positions close at market, so slippage applies.</li>
            <li>• Brute Mode is switched off as a side effect.</li>
            <li>• MT5 polls once per second, so execution is not instant.</li>
          </ul>
        </div>

        <div className="flex justify-end gap-2 border-t border-surface-border px-5 py-4">
          <Button ref={cancelButtonRef} variant="secondary" onClick={onCancel}>
            Cancel
          </Button>
          <Button
            variant="critical"
            onClick={onConfirm}
            disabled={!isArmed}
            loading={isSubmitting}
          >
            {isArmed ? 'Close all positions' : `Wait ${secondsRemaining}s`}
          </Button>
        </div>
      </div>
    </div>
  );
}
