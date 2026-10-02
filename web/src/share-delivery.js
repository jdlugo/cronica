export async function deliverShare({ navigatorRef, shareData, fallbackText, presentFallback }) {
  if (typeof presentFallback !== "function") throw new Error("A share fallback presenter is required");

  if (typeof navigatorRef?.share === "function") {
    try {
      await navigatorRef.share(shareData);
      return {
        outcome: "shared",
        format: Array.isArray(shareData.files) && shareData.files.length ? "image" : "text",
      };
    } catch (error) {
      if (error?.name === "AbortError") return { outcome: "cancelled", format: "native" };
    }
  }

  presentFallback(fallbackText);
  return { outcome: "fallback", format: "copy_panel" };
}
