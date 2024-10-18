#ifndef _CYAN_TYPES_H
#define _CYAN_TYPES_H

#if defined(__x86_64__) || defined(__x86_64) || defined(__amd64__) || defined(__amd64)
#define CYAN_ARCH_x86
#define CYAN_ARCH_x86_64
#define CYAN_64BITS
#elif defined(i386) || defined(__i386) || defined(__i386__)
#define CYAN_ARCH_x86
#define CYAN_32BITS
#elif defined(__aarch64__)
#define CYAN_ARCH_ARM
#define CYAN_ARCH_AARCH64
#define CYAN_64BITS
#elif defined(__arm__)
#define CYAN_ARCH_ARM
#define CYAN_32BITS
#endif

typedef char char8_t;
// typedef wchar_t char16_t;

#ifdef CYAN_64BITS

typedef char                int8_t;
typedef short               int16_t;
typedef int                 int32_t;
typedef long long           int64_t;

typedef unsigned char       uint8_t;
typedef unsigned short      uint16_t;
typedef unsigned int        uint32_t;
typedef unsigned long long  uint64_t;

#else

typedef char                int8_t;
typedef short               int16_t;
typedef int                 int32_t;
// typedef long long           int64_t;

typedef unsigned char       uint8_t;
typedef unsigned short      uint16_t;
typedef unsigned int        uint32_t;
typedef unsigned long long  uint64_t;

#endif

#endif