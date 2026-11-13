import Image from "next/image";

/**
 * The logo shown beside the app name throughout the web app.
 *
 * This is the official Sangguniang Bayan ng Mabini seal (`public/seal.png`) and
 * is also the browser/app icon for the staff and admin web app. It sits on a
 * white disc so its black ring and colours stay legible on the purple header.
 */
export function BrandMark({
  size = "md",
  priority = false,
}: {
  size?: "sm" | "md";
  priority?: boolean;
}) {
  const box = size === "sm" ? "h-9 w-9" : "h-10 w-10";
  const pixels = size === "sm" ? 36 : 40;

  return (
    <span
      className={`grid ${box} shrink-0 place-items-center overflow-hidden rounded-full bg-white p-1`}
    >
      <Image
        src="/seal.png"
        alt="Sangguniang Bayan ng Mabini official seal"
        width={pixels}
        height={pixels}
        priority={priority}
        className="h-full w-full object-contain"
      />
    </span>
  );
}
