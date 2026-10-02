export function resolveScheduleTargetDate(
  scheduleTime: string | Date | undefined,
  now: Date = new Date()
): Date {
  if (scheduleTime) {
    const parsed = new Date(scheduleTime);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed;
    }
  }
  return now;
}

export function isPastPrimaryGenerationWindow(
  targetDate: Date,
  primaryHourUTC = 5,
  primaryMinuteUTC = 5
): boolean {
  const hour = targetDate.getUTCHours();
  const minute = targetDate.getUTCMinutes();
  if (hour > primaryHourUTC) {
    return true;
  }
  if (hour < primaryHourUTC) {
    return false;
  }
  return minute >= primaryMinuteUTC;
}
