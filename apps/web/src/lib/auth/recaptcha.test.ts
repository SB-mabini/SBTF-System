import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { captchaMode, verifyCaptchaToken } from "./recaptcha";

const ORIGINAL_SITE_KEY = process.env.NEXT_PUBLIC_RECAPTCHA_SITE_KEY;
const ORIGINAL_SECRET_KEY = process.env.RECAPTCHA_SECRET_KEY;

beforeEach(() => {
  delete process.env.NEXT_PUBLIC_RECAPTCHA_SITE_KEY;
  delete process.env.RECAPTCHA_SECRET_KEY;
});

afterEach(() => {
  if (ORIGINAL_SITE_KEY === undefined) delete process.env.NEXT_PUBLIC_RECAPTCHA_SITE_KEY;
  else process.env.NEXT_PUBLIC_RECAPTCHA_SITE_KEY = ORIGINAL_SITE_KEY;

  if (ORIGINAL_SECRET_KEY === undefined) delete process.env.RECAPTCHA_SECRET_KEY;
  else process.env.RECAPTCHA_SECRET_KEY = ORIGINAL_SECRET_KEY;

  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe("captchaMode", () => {
  it("is disabled when neither key is set", () => {
    expect(captchaMode()).toBe("disabled");
  });

  it("is configured when both keys are set", () => {
    process.env.NEXT_PUBLIC_RECAPTCHA_SITE_KEY = "site-key";
    process.env.RECAPTCHA_SECRET_KEY = "secret-key";
    expect(captchaMode()).toBe("configured");
  });

  it("is misconfigured when only one key is set", () => {
    process.env.NEXT_PUBLIC_RECAPTCHA_SITE_KEY = "site-key";
    expect(captchaMode()).toBe("misconfigured");

    delete process.env.NEXT_PUBLIC_RECAPTCHA_SITE_KEY;
    process.env.RECAPTCHA_SECRET_KEY = "secret-key";
    expect(captchaMode()).toBe("misconfigured");
  });
});

describe("verifyCaptchaToken", () => {
  it("reports an unconfigured deployment without calling Google", async () => {
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);

    await expect(verifyCaptchaToken("token")).resolves.toEqual({
      ok: false,
      unconfigured: true,
    });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("rejects a missing token without calling Google", async () => {
    process.env.RECAPTCHA_SECRET_KEY = "secret-key";
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);

    await expect(verifyCaptchaToken("")).resolves.toEqual({
      ok: false,
      unconfigured: false,
    });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("accepts a token Google confirms", async () => {
    process.env.RECAPTCHA_SECRET_KEY = "secret-key";
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: true }),
    });
    vi.stubGlobal("fetch", fetchMock);

    await expect(verifyCaptchaToken("token", "203.0.113.7")).resolves.toEqual({
      ok: true,
      unconfigured: false,
    });

    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toBe("https://www.google.com/recaptcha/api/siteverify");
    const body = init.body as URLSearchParams;
    expect(body.get("secret")).toBe("secret-key");
    expect(body.get("response")).toBe("token");
    expect(body.get("remoteip")).toBe("203.0.113.7");
  });

  it("rejects a token Google declines", async () => {
    process.env.RECAPTCHA_SECRET_KEY = "secret-key";
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({ success: false, "error-codes": ["invalid-input-response"] }),
      }),
    );

    await expect(verifyCaptchaToken("token")).resolves.toEqual({
      ok: false,
      unconfigured: false,
    });
  });

  it("treats a network or HTTP failure as a failed verification", async () => {
    process.env.RECAPTCHA_SECRET_KEY = "secret-key";

    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("network down")));
    await expect(verifyCaptchaToken("token")).resolves.toEqual({
      ok: false,
      unconfigured: false,
    });

    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false }));
    await expect(verifyCaptchaToken("token")).resolves.toEqual({
      ok: false,
      unconfigured: false,
    });
  });
});
