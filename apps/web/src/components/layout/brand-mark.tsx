import Image from "next/image";

/**
 * The municipal logo.
 *
 * `public/logo.jpg` is an opaque JPEG: JPEG cannot carry an alpha channel and the
 * artwork sits on a plain white field. Every slot that shows the logo is a dark
 * purple header (`--color-primary: #271564`), so the artwork is always presented on
 * a white plate. Without that plate the logo reads as a white rectangle rather than
 * a mark. Swap this for a transparent PNG if one is ever supplied and the plate can
 * be dropped here alone.
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
      className={`grid ${box} shrink-0 place-items-center overflow-hidden rounded-lg bg-white`}
    >
      <Image
        src="/logo.jpg"
        alt=""
        width={pixels}
        height={pixels}
        priority={priority}
        className="h-full w-full object-contain"
      />
    </span>
  );
}