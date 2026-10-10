#include <stdint.h>

#ifndef _WIN32
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

#else

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

static uint64_t hotpath_windows_mul_div_u64(
    uint64_t value, uint64_t multiplier, uint64_t denominator) {
  // value is a remainder smaller than denominator. Build the exact quotient
  // one multiplier bit at a time so neither value*multiplier nor an
  // intermediate remainder sum can overflow 64 bits.
  uint64_t quotient = 0;
  uint64_t remainder = 0;
  for (int bit = 63; bit >= 0; --bit) {
    quotient <<= 1;

    uint64_t carry;
    if (remainder >= denominator - remainder) {
      remainder -= denominator - remainder;
      carry = 1;
    } else {
      remainder += remainder;
      carry = 0;
    }
    quotient += carry;

    if ((multiplier >> bit) & 1U) {
      if (value >= denominator - remainder) {
        remainder -= denominator - value;
        quotient += 1;
      } else {
        remainder += value;
      }
    }
  }
  return quotient;
}

int64_t hotpath_windows_ticks_to_ns(int64_t ticks, int64_t frequency) {
  if (ticks < 0 || frequency <= 0) {
    return -1;
  }

  const uint64_t ns_per_second = 1000000000ULL;
  const uint64_t counter_ticks = (uint64_t)ticks;
  const uint64_t ticks_per_second = (uint64_t)frequency;
  const uint64_t whole_seconds = counter_ticks / ticks_per_second;
  const uint64_t remainder = counter_ticks % ticks_per_second;
  if (whole_seconds > (uint64_t)INT64_MAX / ns_per_second) {
    return -1;
  }

  const uint64_t whole_ns = whole_seconds * ns_per_second;
  const uint64_t fractional_ns =
      hotpath_windows_mul_div_u64(remainder, ns_per_second, ticks_per_second);
  if (fractional_ns > (uint64_t)INT64_MAX - whole_ns) {
    return -1;
  }
  return (int64_t)(whole_ns + fractional_ns);
}

int64_t hotpath_windows_resolution_ns(int64_t frequency) {
  if (frequency <= 0) {
    return -1;
  }
  const uint64_t ns_per_second = 1000000000ULL;
  const uint64_t ticks_per_second = (uint64_t)frequency;
  uint64_t resolution = ns_per_second / ticks_per_second;
  if (ns_per_second % ticks_per_second != 0) {
    resolution += 1;
  }
  // The native API reports integral nanoseconds; sub-nanosecond counter
  // periods therefore have a representable resolution of one nanosecond.
  if (resolution == 0) {
    resolution = 1;
  }
  return (int64_t)resolution;
}

int64_t hotpath_native_clock_now_ns(void) {
  LARGE_INTEGER counter;
  LARGE_INTEGER frequency;
  if (!QueryPerformanceCounter(&counter) ||
      !QueryPerformanceFrequency(&frequency)) {
    return -1;
  }
  return hotpath_windows_ticks_to_ns(counter.QuadPart, frequency.QuadPart);
}

int64_t hotpath_native_clock_resolution_ns(void) {
  LARGE_INTEGER frequency;
  if (!QueryPerformanceFrequency(&frequency)) {
    return -1;
  }
  return hotpath_windows_resolution_ns(frequency.QuadPart);
}

#endif
