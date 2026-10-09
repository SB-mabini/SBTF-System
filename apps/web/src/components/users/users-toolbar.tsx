"use client";

import { useState } from "react";
import { UserPlus } from "lucide-react";

import { Button } from "@/components/ui";
import { CreateStaffDialog } from "@/components/users/create-staff-dialog";

/**
 * The only entry point for creating municipal accounts.
 *
 * Mounted at the top of the administrator users page. Self-registration stays
 * driver-only in the mobile app; this button is how staff and administrator
 * accounts come into existence, via createStaffUserAction → the admin-users
 * Edge Function.
 */
export function UsersToolbar() {
  const [open, setOpen] = useState(false);

  return (
    <>
      <div className="flex justify-end">
        <Button onClick={() => setOpen(true)}>
          <UserPlus className="h-4 w-4" />
          Create account
        </Button>
      </div>
      <CreateStaffDialog open={open} onClose={() => setOpen(false)} />
    </>
  );
}
