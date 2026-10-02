export function contentAttribution(session, fallbackPublicationId) {
  return {
    publication_id: session?.publicationId || fallbackPublicationId,
    content_version: session?.contentVersion || session?.versionId || "unknown",
  };
}
