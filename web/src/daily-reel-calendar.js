const PUBLICATION_BOUNDARY_HOURS_UTC = 5;

export function dailyReelPublicationId(date = new Date()) {
  const shifted = new Date(date.getTime() - PUBLICATION_BOUNDARY_HOURS_UTC * 60 * 60 * 1000);
  return shifted.toISOString().slice(0, 10);
}
