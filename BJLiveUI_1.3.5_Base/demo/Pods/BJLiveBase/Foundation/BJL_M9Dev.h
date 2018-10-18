//
//  BJL_M9Dev.h
//  M9Dev
//
//  Created by MingLQ on 2016-04-20.
//  Copyright © 2016 MingLQ <minglq.9@gmail.com>. Released under the MIT license.
//

#import <Foundation/Foundation.h>

// #see M9Dev - https://github.com/iwill/

NS_ASSUME_NONNULL_BEGIN

/* #see `bjl_available` in `BJLiveBase.podspec` - neednot import everywhere
#if (__IPHONE_OS_VERSION_MAX_ALLOWED >= 110000)
    #define bjl_available(VERSIONS, CONDITION) @available VERSIONS
#else
    #define bjl_available(VERSIONS, CONDITION) CONDITION
#endif // */

// for compound statement
#define bjl_return \

// cast
#define bjl_cast(CLASS, OBJECT) ({ (CLASS *)([OBJECT isKindOfClass:[CLASS class]] ? (OBJECT) : nil); })

// struct
// cast to ignore const: bjl_set((CGRect)CGRectZero, { set.size = [self intrinsicContentSize]; })
#define bjl_set(_STRUCT, STATEMENTS) ({ \
    __typeof__(_STRUCT) set = _STRUCT; \
    STATEMENTS \
    set; \
})

// variable arguments
#define bjl_va_each(TYPE, FIRST, BLOCK) { \
    va_list args; \
    va_start(args, FIRST); \
    for (TYPE arg = FIRST; !!arg; arg = va_arg(args, TYPE)) { \
        BLOCK(arg); \
    } \
    va_end(args); \
}

// strongify if nil
// bjl_strongify_ifNil(self) return;
#define bjl_strongify_ifNil(...) \
    bjl_strongify(__VA_ARGS__); \
    if ([NSArray arrayWithObjects:__VA_ARGS__, nil].count != metamacro_argcount(__VA_ARGS__))

// dispatch
/*
static inline dispatch_time_t bjl_dispatch_time_in_seconds(NSTimeInterval seconds) {
    return dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC));
}
static inline void bjl_dispatch_after_seconds(NSTimeInterval seconds, dispatch_queue_t queue, dispatch_block_t block) {
    dispatch_after(bjl_dispatch_time_in_seconds(seconds), queue ?: dispatch_get_main_queue(), block);
}
*/
static inline void bjl_dispatch_sync_main_queue(dispatch_block_t block) {
    if ([NSThread isMainThread]) block();
    else dispatch_sync(dispatch_get_main_queue(), block);
}
static inline void bjl_dispatch_async_main_queue(dispatch_block_t block) {
    dispatch_async(dispatch_get_main_queue(), block);
}
static inline void bjl_dispatch_async_background_queue(dispatch_block_t block) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), block);
}

// to string
#define BJLStringFromLiteral(...)   @#__VA_ARGS__
#define BJLCStringFromLiteral(...)  #__VA_ARGS__
#define BJLStringFromValue(VALUE, DEFAULT_VALUE)    ({ VALUE ? [@(VALUE) description] : DEFAULT_VALUE; })
#define BJLObjectFromValue(VALUE, DEFAULT_VALUE)    ({ VALUE ? @(VALUE) : DEFAULT_VALUE; })

// !!!: use DEFAULT_VALUE if PREPROCESSOR is undefined or its value is same to itself
#define BJLStringFromPreprocessor(PREPROCESSOR, DEFAULT_VALUE) ({ \
    NSString *string = BJLStringFromLiteral(PREPROCESSOR); \
    bjl_return [string isEqualToString:@#PREPROCESSOR] ? DEFAULT_VALUE : string; \
})

// #define NSNULL [NSNull null]

// version comparison
// BJLVersionLT(@"10", @"10.0"));    // YES - X
// BJLVersionLT(@"10", @"10"));      // NO  - √
#define BJLVersionEQ(A, B) ({ [A compare:B options:NSNumericSearch] == NSOrderedSame; })
#define BJLVersionLT(A, B) ({ [A compare:B options:NSNumericSearch] <  NSOrderedSame; })
#define BJLVersionGT(A, B) ({ [A compare:B options:NSNumericSearch] >  NSOrderedSame; })
#define BJLVersionLE(A, B) ({ [A compare:B options:NSNumericSearch] <= NSOrderedSame; })
#define BJLVersionGE(A, B) ({ [A compare:B options:NSNumericSearch] >= NSOrderedSame; })

// milliseconds
typedef long long BJLMilliseconds;
#define BJL_MSEC_PER_SEC            1000ull
#define BJLMillisecondsSince1970    BJLMillisecondsFromTimeInterval(NSTimeIntervalSince1970)
static inline BJLMilliseconds BJLMillisecondsFromTimeInterval(NSTimeInterval timeInterval) {
    return (BJLMilliseconds)(timeInterval * BJL_MSEC_PER_SEC);
}
static inline NSTimeInterval BJLTimeIntervalFromMilliseconds(BJLMilliseconds milliseconds) {
    return (NSTimeInterval)milliseconds / BJL_MSEC_PER_SEC;
}

// to string
#define BJLStringFromLiteral(...)   @#__VA_ARGS__
#define BJLCStringFromLiteral(...)  #__VA_ARGS__
#define BJLStringFromValue(VALUE, DEFAULT_VALUE)    ({ VALUE ? [@(VALUE) description] : DEFAULT_VALUE; })
#define BJLObjectFromValue(VALUE, DEFAULT_VALUE)    ({ VALUE ? @(VALUE) : DEFAULT_VALUE; })

// !!!: use DEFAULT_VALUE if PREPROCESSOR is undefined or its value is same to itself
#define BJLStringFromPreprocessor(PREPROCESSOR, DEFAULT_VALUE) ({ \
    NSString *string = BJLStringFromLiteral(PREPROCESSOR); \
    bjl_return [string isEqualToString:@#PREPROCESSOR] ? DEFAULT_VALUE : string; \
})

// #define NSNULL [NSNull null]

// version comparison
// BJLVersionLT(@"10", @"10.0"));    // YES - X
// BJLVersionLT(@"10", @"10"));      // NO  - √
#define BJLVersionEQ(A, B) ({ [A compare:B options:NSNumericSearch] == NSOrderedSame; })
#define BJLVersionLT(A, B) ({ [A compare:B options:NSNumericSearch] <  NSOrderedSame; })
#define BJLVersionGT(A, B) ({ [A compare:B options:NSNumericSearch] >  NSOrderedSame; })
#define BJLVersionLE(A, B) ({ [A compare:B options:NSNumericSearch] <= NSOrderedSame; })
#define BJLVersionGE(A, B) ({ [A compare:B options:NSNumericSearch] >= NSOrderedSame; })

// safe range
static inline NSRange BJLMakeSafeRange(NSUInteger loc, NSUInteger len, NSUInteger length) {
    loc = MIN(loc, length);
    len = MIN(len, length - loc);
    return NSMakeRange(loc, len);
}
static inline NSRange BJLSafeRangeForLength(NSRange range, NSUInteger length) {
    return BJLMakeSafeRange(range.location, range.length, length);
}

// this class
#define BJL_THIS_CLASS_NAME ({ \
    static NSString *ClassName = nil; \
    if (!ClassName) {\
        NSString *prettyFunction = [NSString stringWithUTF8String:__PRETTY_FUNCTION__]; \
        NSUInteger loc = [prettyFunction rangeOfString:@"["].location + 1; \
        NSUInteger len = [prettyFunction rangeOfString:@" "].location - loc; \
        NSRange range = BJLMakeSafeRange(loc, len, prettyFunction.length); \
        ClassName = [prettyFunction substringWithRange:range]; \
    } \
    ClassName; \
})
#define BJL_THIS_CLASS NSClassFromString(BJL_THIS_CLASS_NAME)

/**
 *  M9TuplePack & M9TupleUnpack
 *  1. define:
 *      - (BJLTupleType(BOOL state1, BOOL state2))states;
 *  or:
 *      - (BJLTuple<BJLTupleGeneric(BOOL state1, BOOL state2> *)states;
 *  or:
 *      - (BJLTuple<void (^)(BOOL state1, BOOL state2> *)states;
 *  2. pack:
 *      BOOL state1 = self.state1, state2 = self.state2;
 *      return BJLTuplePack((BOOL, BOOL), state1, state2);
 *  3. unpack:
 *      BJLTupleUnpack(tuple) = ^(BOOL state1, BOOL state2) {
 *          // ...
 *      };
 * !!!:
 *  1. BJLTuplePack 中不要使用 `.`，否则会断言失败，例如
 *      BJLTuplePack((BOOL, BOOL), self.state1, self.state2);
 *  原因是
 *      a. self 将被 tuple 持有、直到 tuple 被释放
 *      b. self.state1、self.state2 的值在拆包时才读取，取到的值可能与打包时不同
 *  为避免出现不可预期的结果，定义临时变量提前读取属性值、然后打包，例如
 *      BOOL state1 = self.state1, state2 = self.state2;
 *      BJLTuple *tuple = BJLTuplePack((BOOL, BOOL), state1, state2);
 *  2. BJLTupleUnpack 中不需要 weakify、strongify，因为 unpack block 会被立即执行
 */
// 1. define:
/** - (BJLTupleType(NSString *string, NSInteger integer))aTuple; */
#define BJLTupleType(...)       BJLTuple<void (^)(__VA_ARGS__)> *
/** - (BJLTuple<BJLTupleGeneric(NSString *string, NSInteger integer)> *)aTuple; */
#define BJLTupleGeneric         void (^)
// 2. pack:
#define BJLTuplePack(TYPE, ...) _BJLTuplePack(void (^)TYPE, __VA_ARGS__)
#define _BJLTuplePack(TYPE, ...) ({\
    NSCAssert([BJLStringFromLiteral(__VA_ARGS__) rangeOfString:@"."].location == NSNotFound, \
              @"DONOT use `.` in BJLTuplePack(%@)", BJLStringFromLiteral(__VA_ARGS__)); \
    [BJLTuple tupleWithPack:^(BJLTupleUnpackBlock NS_NOESCAPE unpack) { \
        if (unpack) ((TYPE)unpack)(__VA_ARGS__); \
    }]; \
})
// 3. unpack:
// 用 ([BJLTuple defaultTuple], TUPLE) 而不是 (TUPLE ?: [BJLTuple defaultTuple])，因为后者会导致 TUPLE 被编译器认为是 nullable 的
#define BJLTupleUnpack(TUPLE)   ([BJLTuple defaultTuple], TUPLE).unpack
// 4. internal:
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wstrict-prototypes"
typedef void (^BJLTupleUnpackBlock)(/* ... */);
#pragma clang diagnostic pop
typedef void (^BJLTuplePackBlock)(BJLTupleUnpackBlock NS_NOESCAPE unpack);
@interface BJLTuple<T> : NSObject
@property (nonatomic/* , writeonly */, assign, setter=unpack:) id/* <T NS_NOESCAPE> */ unpack;
+ (instancetype)tupleWithPack:(BJLTuplePackBlock)pack;
+ (instancetype)defaultTuple;
@end

// RACTupleUnpack without unused warning
#define BJL_RACTupleUnpack(...) \
_Pragma("GCC diagnostic push") \
_Pragma("GCC diagnostic ignored \"-Wunused-variable\"") \
RACTupleUnpack(__VA_ARGS__) \
_Pragma("GCC diagnostic pop")

/* DEPRECATED */

#define bjl_NSObjectFromValue(VALUE, DEFAULT_VALUE) ({ VALUE ? @(VALUE) : DEFAULT_VALUE; })
#define bjl_NSStringFromValue(VALUE, DEFAULT_VALUE) ({ VALUE ? [@(VALUE) description] : DEFAULT_VALUE; })
#define bjl_NSStringFromLiteral(LITERAL)    @#LITERAL
#define bjl_NSStringFromPreprocessor(PREPROCESSOR, DEFAULT_VALUE) ({ \
    NSString *string = BJLStringFromLiteral(PREPROCESSOR); \
    bjl_return [string isEqualToString:@#PREPROCESSOR] ? DEFAULT_VALUE : string; \
})

#define bjl_NSVersionEQ(A, B) ({ [A compare:B options:NSNumericSearch] == NSOrderedSame; })
#define bjl_NSVersionLT(A, B) ({ [A compare:B options:NSNumericSearch] <  NSOrderedSame; })
#define bjl_NSVersionGT(A, B) ({ [A compare:B options:NSNumericSearch] >  NSOrderedSame; })
#define bjl_NSVersionLE(A, B) ({ [A compare:B options:NSNumericSearch] <= NSOrderedSame; })
#define bjl_NSVersionGE(A, B) ({ [A compare:B options:NSNumericSearch] >= NSOrderedSame; })

#define bjl_structSet(_STRUCT, STATEMENTS) ({ \
    __typeof__(_STRUCT) set = _STRUCT; \
    STATEMENTS \
    set; \
})

#define BJL_NSMakeSafeRange(loc, len, length)   BJLMakeSafeRange(loc, len, length)
#define BJL_NSSafeRangeForLength(range, length) BJLSafeRangeForLength(range, length)

NS_ASSUME_NONNULL_END
