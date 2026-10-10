#ifndef _WIN32

#include <stdint.h>
#include <time.h>

static int64_t hotpath_timespec_to_ns(struct timespec value) {
  if (value.tv_sec < 0 || value.tv_nsec < 0 || value.tv_nsec >= 1000000000L) {
    return -1;
  }
  if ((uint64_t)value.tv_sec > (uint64_t)INT64_MAX / 1000000000ULL) {
    return -1;
  }
  int64_t seconds_ns = (int64_t)value.tv_sec * 1000000000LL;
  int64_t nanoseconds = (int64_t)value.tv_nsec;
  if (nanoseconds > INT64_MAX - seconds_ns) {
    return -1;
  }
  return seconds_ns + nanoseconds;
}

int64_t hotpath_native_clock_now_ns(void) {
  struct timespec value;
  if (clock_gettime(CLOCK_MONOTONIC, &value) != 0) {
    return -1;
  }
  return hotpath_timespec_to_ns(value);
}

int64_t hotpath_native_clock_resolution_ns(void) {
  struct timespec value;
  if (clock_getres(CLOCK_MONOTONIC, &value) != 0) {
    return -1;
  }
  return hotpath_timespec_to_ns(value);
}

#endif
