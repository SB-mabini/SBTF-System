"use client";

import { useEffect, type ReactNode } from "react";
import { AlertTriangle, X } from "lucide-react";

import { Button } from "@/components/ui";

export function Modal({
  open,
  title,
  description,
  onClose,
  children,
  footer,
  width = "md",
}: {
  open: boolean;
  title: string;
  description?: string;
  onClose: () => void;
  children?: ReactNode;
  footer?: ReactNode;
  width?: "sm" | "md" | "lg";
}) {
  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") onClose();
    }
    if (open) document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  if (!open) return null;

  const maxWidth = width === "sm" ? "max-w-sm" : width === "lg" ? "max-w-2xl" : "max-w-lg";

  return (
    <div className="fixed inset-0 z-40 flex items-start justify-center overflow-y-auto bg-ink/40 p-4 sm:items-center">
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className={`w-full ${maxWidth} rounded-xl border border-line bg-white shadow-raised`}
      >
        <div className="flex items-start justify-between gap-4 border-b border-line px-5 py-4">
          <div>
            <h2 className="text-[0.9375rem] font-semibold text-ink">{title}</h2>
            {description ? <p className="mt-0.5 text-[0.8125rem] text-muted">{description}</p> : null}
          </div>
          <button
            type="button"
            onClick={onClose}
            className="rounded p-1 text-muted hover:bg-page"
            aria-label="Close"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        {children ? <div className="px-5 py-4">{children}</div> : null}

        {footer ? (
          <div className="flex justify-end gap-2 border-t border-line bg-page/60 px-5 py-3">{footer}</div>
        ) : null}
      </div>
    </div>
  );
}

export function ConfirmDialog({
  open,
  title,
  message,
  confirmLabel = "Confirm",
  cancelLabel = "Cancel",
  destructive = false,
  loading = false,
  onConfirm,
  onCancel,
  children,
}: {
  open: boolean;
  title: string;
  message: string;
  confirmLabel?: string;
  cancelLabel?: string;
  destructive?: boolean;
  loading?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
  children?: ReactNode;
}) {
  return (
    <Modal
      open={open}
      title={title}
      onClose={onCancel}
      footer={
        <>
          <Button variant="outline" onClick={onCancel} disabled={loading}>
            {cancelLabel}
          </Button>
          <Button variant={destructive ? "danger" : "primary"} onClick={onConfirm} loading={loading}>
            {confirmLabel}
          </Button>
        </>
      }
    >
      <div className="flex gap-3">
        <span
          className={`mt-0.5 rounded-md p-2 ${
            destructive ? "bg-secondary-50 text-secondary-600" : "bg-primary-50 text-primary-700"
          }`}
        >
          <AlertTriangle className="h-4 w-4" />
        </span>
        <p className="text-[0.875rem] text-ink">{message}</p>
      </div>
      {children ? <div className="mt-4">{children}</div> : null}
    </Modal>
  );
}
