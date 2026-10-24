#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>
#import <unistd.h>

static const NSTimeInterval kIdleWindow = 120.0;
static const NSTimeInterval kDailyTarget = 10.0 * 60.0 * 60.0;
static BOOL LaunchedInBackground = NO;
static BOOL UseEnglish = NO;

static NSString *L(NSString *chinese, NSString *english) {
    return UseEnglish ? english : chinese;
}

static NSString *DateKey(NSDate *date) {
    static NSDateFormatter *formatter;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        formatter = [NSDateFormatter new];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.dateFormat = @"yyyy-MM-dd";
    });
    return [formatter stringFromDate:date];
}

static NSDate *StartOfDay(NSDate *date) {
    return [[NSCalendar currentCalendar] startOfDayForDate:date];
}

static NSDate *StartOfWeek(NSDate *date) {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *day = [calendar startOfDayForDate:date];
    NSInteger weekday = [calendar component:NSCalendarUnitWeekday fromDate:day];
    NSInteger daysSinceMonday = (weekday + 5) % 7;
    return [calendar dateByAddingUnit:NSCalendarUnitDay value:-daysSinceMonday toDate:day options:0];
}

typedef NS_ENUM(NSInteger, StatisticsScale) {
    StatisticsScaleWeek = 0,
    StatisticsScaleMonth = 1,
    StatisticsScaleYear = 2
};

static NSDate *DateFromKey(NSString *key) {
    static NSDateFormatter *formatter;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        formatter = [NSDateFormatter new];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.dateFormat = @"yyyy-MM-dd";
    });
    return [formatter dateFromString:key];
}

static NSDate *StatisticsPeriodStart(NSDate *date, StatisticsScale scale) {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    if (scale == StatisticsScaleWeek) return StartOfWeek(date);
    NSCalendarUnit units = scale == StatisticsScaleMonth
        ? (NSCalendarUnitYear | NSCalendarUnitMonth)
        : NSCalendarUnitYear;
    NSDateComponents *parts = [calendar components:units fromDate:date];
    parts.day = 1;
    return [calendar startOfDayForDate:[calendar dateFromComponents:parts]];
}

static NSDate *StatisticsPeriodEnd(NSDate *date, StatisticsScale scale) {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *start = StatisticsPeriodStart(date, scale);
    NSCalendarUnit unit = scale == StatisticsScaleWeek ? NSCalendarUnitDay
        : (scale == StatisticsScaleMonth ? NSCalendarUnitMonth : NSCalendarUnitYear);
    NSInteger amount = scale == StatisticsScaleWeek ? 7 : 1;
    return [calendar dateByAddingUnit:unit value:amount toDate:start options:0];
}

static NSString *StatisticsPeriodLabel(NSDate *date, StatisticsScale scale) {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *start = StatisticsPeriodStart(date, scale);
    NSDate *end = [calendar dateByAddingUnit:NSCalendarUnitDay value:-1 toDate:StatisticsPeriodEnd(date, scale) options:0];
    NSDateComponents *a = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:start];
    NSDateComponents *b = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:end];
    if (scale == StatisticsScaleYear) return UseEnglish
        ? [NSString stringWithFormat:@"%ld", (long)a.year]
        : [NSString stringWithFormat:@"%ld年", (long)a.year];
    if (scale == StatisticsScaleMonth) return UseEnglish
        ? [NSString stringWithFormat:@"%ld-%02ld", (long)a.year, (long)a.month]
        : [NSString stringWithFormat:@"%ld年%ld月", (long)a.year, (long)a.month];
    if (a.year == b.year) {
        if (UseEnglish) return [NSString stringWithFormat:@"%ld-%02ld-%02ld – %02ld-%02ld", (long)a.year, (long)a.month, (long)a.day, (long)b.month, (long)b.day];
        return [NSString stringWithFormat:@"%ld年%ld月%ld日－%ld月%ld日", (long)a.year, (long)a.month, (long)a.day, (long)b.month, (long)b.day];
    }
    if (UseEnglish) return [NSString stringWithFormat:@"%ld-%02ld-%02ld – %ld-%02ld-%02ld", (long)a.year, (long)a.month, (long)a.day, (long)b.year, (long)b.month, (long)b.day];
    return [NSString stringWithFormat:@"%ld年%ld月%ld日－%ld年%ld月%ld日", (long)a.year, (long)a.month, (long)a.day, (long)b.year, (long)b.month, (long)b.day];
}

static BOOL DateKeyIsInRange(NSString *key, NSDate *start, NSDate *end) {
    NSDate *date = DateFromKey(key);
    return date && [date compare:start] != NSOrderedAscending && [date compare:end] == NSOrderedAscending;
}

static NSDictionary<NSString *, NSNumber *> *AggregateCategoryTotals(
    NSDictionary<NSString *, NSNumber *> *daily,
    NSDictionary<NSString *, NSNumber *> *computer,
    NSArray<NSDictionary *> *manual,
    NSDate *start,
    NSDate *end
) {
    double recordedTotal = 0, computerTotal = 0, classTotal = 0, wholePlantTotal = 0, organTotal = 0;
    for (NSString *key in daily) if (DateKeyIsInRange(key, start, end)) recordedTotal += [daily[key] doubleValue];
    for (NSString *key in computer) if (DateKeyIsInRange(key, start, end)) computerTotal += [computer[key] doubleValue];
    for (NSDictionary *entry in manual) {
        NSString *key = entry[@"date"];
        if (![key isKindOfClass:[NSString class]] || !DateKeyIsInRange(key, start, end)) continue;
        double seconds = [entry[@"totalSeconds"] doubleValue];
        NSString *type = entry[@"type"];
        if ([type isEqual:@"class"]) classTotal += seconds;
        else if ([type isEqual:@"whole_plant_photo"]) wholePlantTotal += seconds;
        else if ([type isEqual:@"organ_photo"]) organTotal += seconds;
    }
    double known = computerTotal + classTotal + wholePlantTotal + organTotal;
    if (recordedTotal > known) computerTotal += recordedTotal - known;
    double total = computerTotal + classTotal + wholePlantTotal + organTotal;
    return @{
        @"total": @(total),
        @"computer": @(computerTotal),
        @"class": @(classTotal),
        @"whole_plant_photo": @(wholePlantTotal),
        @"organ_photo": @(organTotal)
    };
}

static NSArray<NSDate *> *ElapsedWeekDates(NSDate *date) {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *monday = StartOfWeek(date);
    NSDate *today = StartOfDay(date);
    NSInteger count = [[calendar components:NSCalendarUnitDay fromDate:monday toDate:today options:0] day] + 1;
    NSMutableArray *dates = [NSMutableArray array];
    for (NSInteger i = 0; i < MAX(count, 1); i++) {
        [dates addObject:[calendar dateByAddingUnit:NSCalendarUnitDay value:i toDate:monday options:0]];
    }
    return dates;
}

static NSString *ClockText(NSTimeInterval seconds) {
    NSInteger minutes = MAX(0, (NSInteger)seconds / 60);
    return [NSString stringWithFormat:@"%ld:%02ld", (long)(minutes / 60), (long)(minutes % 60)];
}

static NSString *ChineseDuration(NSTimeInterval seconds) {
    NSInteger minutes = MAX(0, (NSInteger)seconds / 60);
    NSInteger hours = minutes / 60;
    NSInteger remainder = minutes % 60;
    if (hours == 0) return UseEnglish
        ? [NSString stringWithFormat:@"%ld min", (long)remainder]
        : [NSString stringWithFormat:@"%ld 分钟", (long)remainder];
    if (remainder == 0) return UseEnglish
        ? [NSString stringWithFormat:@"%ld hr", (long)hours]
        : [NSString stringWithFormat:@"%ld 小时", (long)hours];
    return UseEnglish
        ? [NSString stringWithFormat:@"%ld hr %ld min", (long)hours, (long)remainder]
        : [NSString stringWithFormat:@"%ld 小时 %ld 分钟", (long)hours, (long)remainder];
}

static NSString *TooltipDateText(NSDate *date) {
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:UseEnglish ? @"en_US" : @"zh_CN"];
    formatter.dateFormat = UseEnglish ? @"EEE, MMM d, yyyy" : @"yyyy年M月d日 EEEE";
    return [formatter stringFromDate:date];
}

static NSArray<NSDictionary *> *HeatmapMonthMarks(NSDate *start, NSDate *today) {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *parts = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth) fromDate:start];
    parts.day = 1;
    NSDate *month = [calendar dateFromComponents:parts];
    if ([month compare:start] == NSOrderedAscending) {
        month = [calendar dateByAddingUnit:NSCalendarUnitMonth value:1 toDate:month options:0];
    }

    NSMutableArray<NSDictionary *> *marks = [NSMutableArray array];
    while ([month compare:today] != NSOrderedDescending) {
        NSInteger dayOffset = [[calendar components:NSCalendarUnitDay fromDate:start toDate:month options:0] day];
        NSInteger monthNumber = [calendar component:NSCalendarUnitMonth fromDate:month];
        [marks addObject:@{
            @"column": @(MAX(0, dayOffset / 7)),
            @"label": UseEnglish ? [NSString stringWithFormat:@"%ld", (long)monthNumber] : [NSString stringWithFormat:@"%ld月", (long)monthNumber]
        }];
        month = [calendar dateByAddingUnit:NSCalendarUnitMonth value:1 toDate:month options:0];
    }
    return marks;
}

static NSTimeInterval ManualWorkSeconds(NSInteger classCount, NSInteger wholePlantCount, NSInteger organCount) {
    return MAX(0, classCount) * 45.0 * 60.0
        + MAX(0, wholePlantCount) * 3.0 * 60.0 * 60.0
        + MAX(0, organCount) * 30.0 * 60.0;
}

static NSArray<NSDictionary *> *DefaultManualWorkTypes(void) {
    return @[
        @{@"id": @"class", @"name": @"给学生上课", @"unitMinutes": @45},
        @{@"id": @"whole_plant_photo", @"name": @"完整植物拍摄", @"unitMinutes": @180},
        @{@"id": @"organ_photo", @"name": @"单独器官拍摄", @"unitMinutes": @30}
    ];
}

static NSString *ManualTypeDisplayName(NSDictionary *definition) {
    NSString *identifier = definition[@"id"];
    NSString *name = definition[@"name"];
    if ([identifier isEqual:@"class"] && [name isEqual:@"给学生上课"]) return L(@"给学生上课", @"Teaching");
    if ([identifier isEqual:@"whole_plant_photo"] && [name isEqual:@"完整植物拍摄"]) return L(@"完整植物拍摄", @"Whole Plant Photo");
    if ([identifier isEqual:@"organ_photo"] && [name isEqual:@"单独器官拍摄"]) return L(@"单独器官拍摄", @"Plant Organ Photo");
    return name;
}

static NSTimeInterval ConfiguredManualSeconds(NSArray<NSDictionary *> *types, NSArray<NSNumber *> *counts) {
    NSTimeInterval total = 0;
    NSInteger limit = MIN(types.count, counts.count);
    for (NSInteger index = 0; index < limit; index++) {
        NSInteger count = MAX(0, counts[index].integerValue);
        NSInteger minutes = MAX(0, [types[index][@"unitMinutes"] integerValue]);
        total += count * minutes * 60.0;
    }
    return total;
}

@interface WorkTimeEngine : NSObject
@property NSMutableDictionary<NSString *, NSNumber *> *dailySeconds;
@property NSMutableDictionary<NSString *, NSNumber *> *computerSeconds;
@property NSMutableArray<NSDictionary *> *manualEntries;
@property NSMutableArray<NSMutableDictionary *> *manualWorkTypes;
@property NSURL *dataFileURL;
@property BOOL active;
@property NSString *activityLabel;
@property NSDate *manualActiveUntil;
@property NSDate *lastTick;
@property NSTimer *timer;
@property NSInteger tickCount;
@property NSString *manualFeedback;
- (void)start;
- (void)stop;
- (void)save;
- (NSTimeInterval)todaySeconds;
- (NSTimeInterval)weeklyAverage;
- (void)beginManualMinute;
- (NSTimeInterval)recordClasses:(NSInteger)classCount wholePlants:(NSInteger)wholePlantCount organs:(NSInteger)organCount;
- (NSDictionary<NSString *, NSNumber *> *)statisticsFrom:(NSDate *)start to:(NSDate *)end;
- (BOOL)launchAtLogin;
- (void)setLaunchAtLogin:(BOOL)enabled;
@end

@implementation WorkTimeEngine
- (instancetype)init {
    if ((self = [super init])) {
        NSURL *base = [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] firstObject];
        NSURL *folder = [base URLByAppendingPathComponent:@"WorkTime" isDirectory:YES];
        [[NSFileManager defaultManager] createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:nil];
        _dataFileURL = [folder URLByAppendingPathComponent:@"work-time.json"];
        _dailySeconds = [NSMutableDictionary dictionary];
        _computerSeconds = [NSMutableDictionary dictionary];
        _manualEntries = [NSMutableArray array];
        _manualWorkTypes = [NSMutableArray array];
        NSData *storedData = [NSData dataWithContentsOfURL:_dataFileURL];
        NSDictionary *saved = storedData ? [NSJSONSerialization JSONObjectWithData:storedData options:0 error:nil] : nil;
        if ([saved[@"dailySeconds"] isKindOfClass:[NSDictionary class]]) [_dailySeconds addEntriesFromDictionary:saved[@"dailySeconds"]];
        if ([saved[@"computerSeconds"] isKindOfClass:[NSDictionary class]]) [_computerSeconds addEntriesFromDictionary:saved[@"computerSeconds"]];
        if ([saved[@"manualEntries"] isKindOfClass:[NSArray class]]) [_manualEntries addObjectsFromArray:saved[@"manualEntries"]];
        NSArray *savedTypes = [saved[@"manualWorkTypes"] isKindOfClass:[NSArray class]] ? saved[@"manualWorkTypes"] : nil;
        NSArray *typeSource = savedTypes.count == 3 ? savedTypes : DefaultManualWorkTypes();
        NSArray *requiredIDs = @[@"class", @"whole_plant_photo", @"organ_photo"];
        for (NSInteger index = 0; index < 3; index++) {
            NSDictionary *candidate = [typeSource[index] isKindOfClass:[NSDictionary class]] ? typeSource[index] : DefaultManualWorkTypes()[index];
            NSString *name = [candidate[@"name"] isKindOfClass:[NSString class]] ? candidate[@"name"] : DefaultManualWorkTypes()[index][@"name"];
            NSInteger minutes = [candidate[@"unitMinutes"] integerValue];
            if (name.length == 0) name = DefaultManualWorkTypes()[index][@"name"];
            if (minutes < 1 || minutes > 1440) minutes = [DefaultManualWorkTypes()[index][@"unitMinutes"] integerValue];
            [_manualWorkTypes addObject:[@{@"id": requiredIDs[index], @"name": name, @"unitMinutes": @(minutes)} mutableCopy]];
        }
        NSMutableDictionary<NSString *, NSNumber *> *manualByDate = [NSMutableDictionary dictionary];
        for (NSDictionary *entry in _manualEntries) {
            NSString *key = entry[@"date"];
            if (![key isKindOfClass:[NSString class]]) continue;
            manualByDate[key] = @([manualByDate[key] doubleValue] + [entry[@"totalSeconds"] doubleValue]);
        }
        BOOL migrated = NO;
        for (NSString *key in _dailySeconds) {
            if (_computerSeconds[key]) continue;
            _computerSeconds[key] = @(MAX(0, [_dailySeconds[key] doubleValue] - [manualByDate[key] doubleValue]));
            migrated = YES;
        }
        _activityLabel = L(@"暂未检测到主动操作", @"No active input detected yet");
        _manualActiveUntil = [NSDate distantPast];
        _manualFeedback = L(@"选择数量后，点击“记入今天”", @"Choose quantities, then click “Add to Today”");
        if (migrated) [self save];
    }
    return self;
}

- (void)save {
    NSDictionary *root = @{
        @"dailySeconds": self.dailySeconds,
        @"computerSeconds": self.computerSeconds,
        @"manualEntries": self.manualEntries,
        @"manualWorkTypes": self.manualWorkTypes,
        @"lastSavedAt": @([[NSDate date] timeIntervalSince1970]),
        @"version": @4
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:root options:NSJSONWritingPrettyPrinted error:nil];
    [data writeToURL:self.dataFileURL options:NSDataWritingAtomic error:nil];
}

- (NSTimeInterval)inputIdleSeconds {
    CGEventType types[] = {
        kCGEventMouseMoved, kCGEventLeftMouseDown, kCGEventRightMouseDown, kCGEventOtherMouseDown,
        kCGEventLeftMouseDragged, kCGEventRightMouseDragged, kCGEventOtherMouseDragged,
        kCGEventScrollWheel, kCGEventKeyDown, kCGEventKeyUp, kCGEventFlagsChanged
    };
    NSTimeInterval minimum = DBL_MAX;
    for (NSUInteger i = 0; i < sizeof(types) / sizeof(types[0]); i++) {
        minimum = MIN(minimum, CGEventSourceSecondsSinceLastEventType(kCGEventSourceStateHIDSystemState, types[i]));
    }
    return minimum;
}

- (void)tick {
    NSDate *now = [NSDate date];
    NSTimeInterval elapsed = [now timeIntervalSinceDate:self.lastTick];
    self.lastTick = now;
    self.tickCount++;

    NSTimeInterval idle = [self inputIdleSeconds];
    BOOL manualTrigger = [now compare:self.manualActiveUntil] == NSOrderedAscending;
    BOOL shouldCount = idle < kIdleWindow || manualTrigger;
    NSTimeInterval credited = (elapsed > 0 && elapsed <= 5 && shouldCount) ? MIN(elapsed, 2.0) : 0;
    self.active = credited > 0;
    if (credited > 0) {
        NSString *key = DateKey(now);
        self.dailySeconds[key] = @([self.dailySeconds[key] doubleValue] + credited);
        self.computerSeconds[key] = @([self.computerSeconds[key] doubleValue] + credited);
        self.activityLabel = (manualTrigger && idle >= kIdleWindow)
            ? L(@"手动触发", @"Manual trigger")
            : L(@"键盘或鼠标", @"Keyboard or mouse");
    } else {
        self.activityLabel = L(@"已停止计时", @"Timing stopped");
    }
    if (self.tickCount % 15 == 0) [self save];
}

- (void)start {
    if (self.timer) return;
    self.lastTick = [NSDate date];
    __weak typeof(self) weakSelf = self;
    self.timer = [NSTimer timerWithTimeInterval:1 repeats:YES block:^(__unused NSTimer *timer) { [weakSelf tick]; }];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)stop { [self.timer invalidate]; self.timer = nil; [self save]; }
- (NSTimeInterval)todaySeconds { return [self.dailySeconds[DateKey([NSDate date])] doubleValue]; }

- (NSTimeInterval)weeklyAverage {
    NSArray<NSDate *> *dates = ElapsedWeekDates([NSDate date]);
    double total = 0;
    for (NSDate *date in dates) total += [self.dailySeconds[DateKey(date)] doubleValue];
    return dates.count ? total / dates.count : 0;
}

- (NSDictionary<NSString *, NSNumber *> *)statisticsFrom:(NSDate *)start to:(NSDate *)end {
    return AggregateCategoryTotals(self.dailySeconds, self.computerSeconds, self.manualEntries, start, end);
}

- (void)beginManualMinute {
    NSDate *candidate = [[NSDate date] dateByAddingTimeInterval:kIdleWindow];
    if ([candidate compare:self.manualActiveUntil] == NSOrderedDescending) self.manualActiveUntil = candidate;
    self.activityLabel = L(@"手动触发", @"Manual trigger");
}

- (NSTimeInterval)recordClasses:(NSInteger)classCount wholePlants:(NSInteger)wholePlantCount organs:(NSInteger)organCount {
    classCount = MAX(0, classCount);
    wholePlantCount = MAX(0, wholePlantCount);
    organCount = MAX(0, organCount);
    NSArray<NSNumber *> *counts = @[@(classCount), @(wholePlantCount), @(organCount)];
    NSTimeInterval total = ConfiguredManualSeconds(self.manualWorkTypes, counts);
    if (total <= 0) {
        self.manualFeedback = L(@"请先选择至少一项数量", @"Choose at least one item first");
        return 0;
    }

    NSDate *now = [NSDate date];
    NSString *dateKey = DateKey(now);
    NSString *batchID = NSUUID.UUID.UUIDString;
    NSMutableArray *items = [NSMutableArray array];
    for (NSInteger index = 0; index < 3; index++) {
        NSDictionary *definition = self.manualWorkTypes[index];
        [items addObject:@{
            @"type": definition[@"id"],
            @"label": definition[@"name"],
            @"count": counts[index],
            @"unitSeconds": @([definition[@"unitMinutes"] integerValue] * 60)
        }];
    }
    for (NSDictionary *item in items) {
        NSInteger count = [item[@"count"] integerValue];
        if (count == 0) continue;
        NSInteger unitSeconds = [item[@"unitSeconds"] integerValue];
        [self.manualEntries addObject:@{
            @"batchID": batchID,
            @"date": dateKey,
            @"recordedAt": @([now timeIntervalSince1970]),
            @"type": item[@"type"],
            @"label": item[@"label"],
            @"count": @(count),
            @"unitSeconds": @(unitSeconds),
            @"totalSeconds": @(count * unitSeconds)
        }];
    }
    self.dailySeconds[dateKey] = @([self.dailySeconds[dateKey] doubleValue] + total);
    self.manualFeedback = [NSString stringWithFormat:L(@"已记入今天：%@", @"Added today: %@"), ChineseDuration(total)];
    [self save];
    return total;
}

- (BOOL)launchAtLogin {
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/LaunchAgents/com.jianhe.worktime.launchagent.plist"];
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

- (void)setLaunchAtLogin:(BOOL)enabled {
    [NSUserDefaults.standardUserDefaults setBool:enabled forKey:@"AutoLaunchDesired"];
    NSString *folder = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/LaunchAgents"];
    NSString *path = [folder stringByAppendingPathComponent:@"com.jianhe.worktime.launchagent.plist"];
    NSString *domain = [NSString stringWithFormat:@"gui/%d", getuid()];
    NSString *service = [domain stringByAppendingString:@"/com.jianhe.worktime.launchagent"];
    if (enabled) {
        [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
        NSDictionary *plist = @{
            @"Label": @"com.jianhe.worktime.launchagent",
            @"ProgramArguments": @[@"/Applications/工作时钟.app/Contents/MacOS/WorkTime", @"--background"],
            @"RunAtLoad": @YES,
            @"ProcessType": @"Interactive"
        };
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:plist format:NSPropertyListXMLFormat_v1_0 options:0 error:nil];
        [data writeToFile:path atomically:YES];
    } else {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSTask *task = [NSTask new];
        task.executableURL = [NSURL fileURLWithPath:@"/bin/launchctl"];
        task.arguments = enabled ? @[@"bootstrap", domain, path] : @[@"bootout", service];
        [task launchAndReturnError:nil];
        [task waitUntilExit];
    });
}
@end

static NSColor *PanelColor(void) { return [NSColor colorWithRed:0.055 green:0.075 blue:0.067 alpha:1]; }
static NSColor *CardColor(void) { return [NSColor colorWithRed:0.09 green:0.12 blue:0.105 alpha:1]; }
static NSColor *GreenColor(void) { return [NSColor colorWithRed:0.35 green:0.92 blue:0.57 alpha:1]; }
static NSColor *OrangeColor(void) { return [NSColor colorWithRed:1.0 green:0.63 blue:0.25 alpha:1]; }
static NSColor *BlueColor(void) { return [NSColor colorWithRed:0.31 green:0.67 blue:1.0 alpha:1]; }
static NSColor *PurpleColor(void) { return [NSColor colorWithRed:0.72 green:0.50 blue:1.0 alpha:1]; }
static NSColor *PrimaryTextColor(void) { return [NSColor colorWithWhite:0.96 alpha:1]; }
static NSColor *SecondaryTextColor(void) { return [NSColor colorWithWhite:0.78 alpha:1]; }

static void FillRounded(NSRect rect, CGFloat radius, NSColor *color) {
    [color setFill];
    [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius] fill];
}

static NSSize DrawText(NSString *text, NSPoint point, CGFloat size, NSFontWeight weight, NSColor *color) {
    NSDictionary *attrs = @{NSFontAttributeName: [NSFont systemFontOfSize:size weight:weight], NSForegroundColorAttributeName: color};
    NSAttributedString *attributed = [[NSAttributedString alloc] initWithString:text attributes:attrs];
    [attributed drawAtPoint:point];
    return attributed.size;
}

static NSColor *HeatColor(NSTimeInterval seconds) {
    if (seconds < 60) return [NSColor colorWithWhite:1 alpha:0.07];
    if (seconds < 30 * 60) return [NSColor colorWithRed:0.07 green:0.22 blue:0.14 alpha:1];
    if (seconds < 60 * 60) return [NSColor colorWithRed:0.08 green:0.38 blue:0.21 alpha:1];
    if (seconds < 2 * 60 * 60) return [NSColor colorWithRed:0.10 green:0.58 blue:0.31 alpha:1];
    if (seconds < 4 * 60 * 60) return [NSColor colorWithRed:0.16 green:0.74 blue:0.40 alpha:1];
    if (seconds < 7 * 60 * 60) return [NSColor colorWithRed:0.24 green:0.86 blue:0.49 alpha:1];
    if (seconds < 10 * 60 * 60) return [NSColor colorWithRed:0.32 green:0.93 blue:0.56 alpha:1];
    return [NSColor colorWithRed:0.55 green:1.0 blue:0.69 alpha:1];
}

@interface DashboardView : NSView
@property WorkTimeEngine *engine;
@property NSTimer *refreshTimer;
@property NSSegmentedControl *pageTabs;
@property NSSegmentedControl *periodControl;
@property NSButton *previousPeriodButton;
@property NSButton *nextPeriodButton;
@property NSButton *currentPeriodButton;
@property NSDate *statisticsDate;
@property StatisticsScale statisticsScale;
@property NSButton *manualButton;
@property NSButton *loginButton;
@property NSButton *dataButton;
@property NSPopUpButton *classPopup;
@property NSPopUpButton *wholePlantPopup;
@property NSPopUpButton *organPopup;
@property NSButton *recordButton;
@property NSPopUpButton *settingsTypePopup;
@property NSTextField *settingsNameField;
@property NSTextField *settingsMinutesField;
@property NSButton *settingsSaveButton;
@property NSSegmentedControl *languageControl;
@property NSString *settingsFeedback;
@property NSTrackingArea *trackingArea;
@property NSMutableArray<NSDictionary *> *hoverTargets;
@property NSDictionary *hoveredTarget;
@property NSPoint hoverPoint;
@end

@implementation DashboardView
- (instancetype)initWithFrame:(NSRect)frame engine:(WorkTimeEngine *)engine {
    if ((self = [super initWithFrame:frame])) {
        _engine = engine;
        _hoverTargets = [NSMutableArray array];
        self.wantsLayer = YES;

        _statisticsDate = [NSDate date];
        _statisticsScale = StatisticsScaleWeek;
        _pageTabs = [NSSegmentedControl segmentedControlWithLabels:@[L(@"今日总览", @"Overview"), L(@"分类统计", @"Statistics"), L(@"类型设置", @"Settings")]
            trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(pageChanged:)];
        _pageTabs.selectedSegment = 0;
        [self addSubview:_pageTabs];

        _periodControl = [NSSegmentedControl segmentedControlWithLabels:@[L(@"周", @"Week"), L(@"月", @"Month"), L(@"年", @"Year")]
            trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(periodChanged:)];
        _periodControl.selectedSegment = 0;
        [self addSubview:_periodControl];

        _previousPeriodButton = [NSButton buttonWithTitle:L(@"‹ 上一期", @"‹ Previous") target:self action:@selector(movePeriod:)];
        _previousPeriodButton.tag = -1;
        _previousPeriodButton.bezelStyle = NSBezelStyleRounded;
        [self addSubview:_previousPeriodButton];

        _nextPeriodButton = [NSButton buttonWithTitle:L(@"下一期 ›", @"Next ›") target:self action:@selector(movePeriod:)];
        _nextPeriodButton.tag = 1;
        _nextPeriodButton.bezelStyle = NSBezelStyleRounded;
        [self addSubview:_nextPeriodButton];

        _currentPeriodButton = [NSButton buttonWithTitle:L(@"回到本期", @"Current") target:self action:@selector(resetPeriod:)];
        _currentPeriodButton.bezelStyle = NSBezelStyleInline;
        _currentPeriodButton.attributedTitle = [[NSAttributedString alloc] initWithString:_currentPeriodButton.title attributes:@{NSForegroundColorAttributeName: GreenColor()}];
        [self addSubview:_currentPeriodButton];

        _manualButton = [NSButton buttonWithTitle:L(@"电脑计时续算 2 分钟", @"Continue computer time for 2 min") target:self action:@selector(manual:)];
        _manualButton.bezelStyle = NSBezelStyleRounded;
        _manualButton.contentTintColor = GreenColor();
        _manualButton.attributedTitle = [[NSAttributedString alloc] initWithString:_manualButton.title attributes:@{NSForegroundColorAttributeName: GreenColor()}];
        [self addSubview:_manualButton];

        _loginButton = [NSButton checkboxWithTitle:L(@"登录 Mac 时自动启动", @"Launch at Mac login") target:self action:@selector(loginChanged:)];
        _loginButton.attributedTitle = [[NSAttributedString alloc] initWithString:_loginButton.title attributes:@{NSForegroundColorAttributeName: PrimaryTextColor()}];
        _loginButton.state = engine.launchAtLogin ? NSControlStateValueOn : NSControlStateValueOff;
        [self addSubview:_loginButton];

        _dataButton = [NSButton buttonWithTitle:L(@"查看数据文件", @"Show Data File") target:self action:@selector(showData:)];
        _dataButton.bezelStyle = NSBezelStyleInline;
        _dataButton.attributedTitle = [[NSAttributedString alloc] initWithString:_dataButton.title attributes:@{NSForegroundColorAttributeName: GreenColor()}];
        [self addSubview:_dataButton];

        _classPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
        for (NSInteger value = 0; value <= 20; value++) [_classPopup addItemWithTitle:[NSString stringWithFormat:L(@"%ld 次", @"%ld times"), (long)value]];
        [self addSubview:_classPopup];

        _wholePlantPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
        for (NSInteger value = 0; value <= 20; value++) [_wholePlantPopup addItemWithTitle:[NSString stringWithFormat:L(@"%ld 次", @"%ld times"), (long)value]];
        [self addSubview:_wholePlantPopup];

        _organPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
        for (NSInteger value = 0; value <= 20; value++) [_organPopup addItemWithTitle:[NSString stringWithFormat:L(@"%ld 次", @"%ld times"), (long)value]];
        [self addSubview:_organPopup];

        _recordButton = [NSButton buttonWithTitle:L(@"记入今天", @"Add to Today") target:self action:@selector(recordManualWork:)];
        _recordButton.bezelStyle = NSBezelStyleRounded;
        _recordButton.keyEquivalent = @"\r";
        _recordButton.attributedTitle = [[NSAttributedString alloc] initWithString:_recordButton.title attributes:@{NSForegroundColorAttributeName: GreenColor(), NSFontAttributeName: [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold]}];
        [self addSubview:_recordButton];

        _settingsTypePopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
        _settingsTypePopup.target = self;
        _settingsTypePopup.action = @selector(settingsTypeChanged:);
        for (NSDictionary *definition in engine.manualWorkTypes) [_settingsTypePopup addItemWithTitle:ManualTypeDisplayName(definition)];
        [self addSubview:_settingsTypePopup];

        _settingsNameField = [NSTextField textFieldWithString:@""];
        _settingsNameField.placeholderString = L(@"例如：给学生上课", @"For example: Teaching");
        [self addSubview:_settingsNameField];

        _settingsMinutesField = [NSTextField textFieldWithString:@""];
        _settingsMinutesField.placeholderString = L(@"分钟", @"Minutes");
        [self addSubview:_settingsMinutesField];

        _settingsSaveButton = [NSButton buttonWithTitle:L(@"保存设置", @"Save") target:self action:@selector(saveSettingsType:)];
        _settingsSaveButton.bezelStyle = NSBezelStyleRounded;
        _settingsSaveButton.attributedTitle = [[NSAttributedString alloc] initWithString:_settingsSaveButton.title attributes:@{NSForegroundColorAttributeName: GreenColor(), NSFontAttributeName: [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold]}];
        [self addSubview:_settingsSaveButton];
        _languageControl = [NSSegmentedControl segmentedControlWithLabels:@[@"中文", @"English"]
            trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(languageChanged:)];
        _languageControl.selectedSegment = UseEnglish ? 1 : 0;
        [self addSubview:_languageControl];

        _settingsFeedback = L(@"选择一个项目，修改后点击“保存设置”", @"Choose an item, edit it, then click “Save”");
        [self loadSelectedSettingsType];

        __weak typeof(self) weakSelf = self;
        _refreshTimer = [NSTimer timerWithTimeInterval:1 repeats:YES block:^(__unused NSTimer *timer) { [weakSelf setNeedsDisplay:YES]; }];
        [[NSRunLoop mainRunLoop] addTimer:_refreshTimer forMode:NSRunLoopCommonModes];
        [self updateModeControls];
    }
    return self;
}

- (BOOL)isFlipped { return NO; }
- (void)dealloc { [_refreshTimer invalidate]; }

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    self.window.acceptsMouseMovedEvents = YES;
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (self.trackingArea) [self removeTrackingArea:self.trackingArea];
    self.trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect
        options:(NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect)
        owner:self userInfo:nil];
    [self addTrackingArea:self.trackingArea];
}

- (void)addHoverRect:(NSRect)rect title:(NSString *)title detail:(NSString *)detail {
    [self.hoverTargets addObject:@{
        @"rect": [NSValue valueWithRect:rect],
        @"title": title ?: @"",
        @"detail": detail ?: @""
    }];
}

- (void)mouseMoved:(NSEvent *)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    NSDictionary *match = nil;
    for (NSDictionary *target in [self.hoverTargets reverseObjectEnumerator]) {
        if (NSPointInRect(point, [target[@"rect"] rectValue])) { match = target; break; }
    }
    self.hoverPoint = point;
    if (match != self.hoveredTarget) {
        self.hoveredTarget = match;
        [self setNeedsDisplay:YES];
    }
}

- (void)mouseEntered:(NSEvent *)event { [self mouseMoved:event]; }
- (void)mouseDragged:(NSEvent *)event { [self mouseMoved:event]; }

- (void)mouseExited:(NSEvent *)event {
    self.hoveredTarget = nil;
    [self setNeedsDisplay:YES];
}

- (void)drawHoverTooltip {
    if (!self.hoveredTarget) return;
    NSString *title = self.hoveredTarget[@"title"];
    NSString *detail = self.hoveredTarget[@"detail"];
    NSDictionary *titleAttrs = @{NSFontAttributeName: [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold]};
    NSDictionary *detailAttrs = @{NSFontAttributeName: [NSFont systemFontOfSize:13 weight:NSFontWeightBold]};
    CGFloat width = MAX([title sizeWithAttributes:titleAttrs].width, [detail sizeWithAttributes:detailAttrs].width) + 28;
    width = MAX(width, 150);
    CGFloat height = 58;
    CGFloat x = self.hoverPoint.x + 14;
    CGFloat y = self.hoverPoint.y + 16;
    if (x + width > NSWidth(self.bounds) - 10) x = self.hoverPoint.x - width - 14;
    if (y + height > NSHeight(self.bounds) - 10) y = self.hoverPoint.y - height - 14;
    NSRect box = NSMakeRect(MAX(10, x), MAX(10, y), width, height);
    FillRounded(box, 10, [NSColor colorWithRed:0.025 green:0.035 blue:0.030 alpha:0.97]);
    NSBezierPath *border = [NSBezierPath bezierPathWithRoundedRect:box xRadius:10 yRadius:10];
    [[NSColor colorWithWhite:1 alpha:0.16] setStroke]; border.lineWidth = 1; [border stroke];
    DrawText(title, NSMakePoint(NSMinX(box) + 14, NSMaxY(box) - 24), 12, NSFontWeightSemibold, SecondaryTextColor());
    DrawText(detail, NSMakePoint(NSMinX(box) + 14, NSMinY(box) + 10), 13, NSFontWeightBold, PrimaryTextColor());
}

- (void)rebuildCountPopup:(NSPopUpButton *)popup {
    NSInteger selected = popup.indexOfSelectedItem;
    [popup removeAllItems];
    for (NSInteger value = 0; value <= 20; value++) {
        [popup addItemWithTitle:[NSString stringWithFormat:L(@"%ld 次", @"%ld times"), (long)value]];
    }
    [popup selectItemAtIndex:MAX(0, selected)];
}

- (void)applyLanguageToControls {
    [self.pageTabs setLabel:L(@"今日总览", @"Overview") forSegment:0];
    [self.pageTabs setLabel:L(@"分类统计", @"Statistics") forSegment:1];
    [self.pageTabs setLabel:L(@"类型设置", @"Settings") forSegment:2];
    [self.periodControl setLabel:L(@"周", @"Week") forSegment:0];
    [self.periodControl setLabel:L(@"月", @"Month") forSegment:1];
    [self.periodControl setLabel:L(@"年", @"Year") forSegment:2];
    self.previousPeriodButton.title = L(@"‹ 上一期", @"‹ Previous");
    self.nextPeriodButton.title = L(@"下一期 ›", @"Next ›");
    self.currentPeriodButton.attributedTitle = [[NSAttributedString alloc] initWithString:L(@"回到本期", @"Current") attributes:@{NSForegroundColorAttributeName: GreenColor()}];
    self.manualButton.attributedTitle = [[NSAttributedString alloc] initWithString:L(@"电脑计时续算 2 分钟", @"Continue computer time for 2 min") attributes:@{NSForegroundColorAttributeName: GreenColor()}];
    self.loginButton.attributedTitle = [[NSAttributedString alloc] initWithString:L(@"登录 Mac 时自动启动", @"Launch at Mac login") attributes:@{NSForegroundColorAttributeName: PrimaryTextColor()}];
    self.dataButton.attributedTitle = [[NSAttributedString alloc] initWithString:L(@"查看数据文件", @"Show Data File") attributes:@{NSForegroundColorAttributeName: GreenColor()}];
    self.recordButton.attributedTitle = [[NSAttributedString alloc] initWithString:L(@"记入今天", @"Add to Today") attributes:@{NSForegroundColorAttributeName: GreenColor(), NSFontAttributeName: [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold]}];
    self.settingsSaveButton.attributedTitle = [[NSAttributedString alloc] initWithString:L(@"保存设置", @"Save") attributes:@{NSForegroundColorAttributeName: GreenColor(), NSFontAttributeName: [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold]}];
    self.settingsNameField.placeholderString = L(@"例如：给学生上课", @"For example: Teaching");
    self.settingsMinutesField.placeholderString = L(@"分钟", @"Minutes");
    [self rebuildCountPopup:self.classPopup];
    [self rebuildCountPopup:self.wholePlantPopup];
    [self rebuildCountPopup:self.organPopup];
    [self refreshManualTypeControlsKeepingIndex:self.settingsTypePopup.indexOfSelectedItem];
    self.settingsFeedback = L(@"选择一个项目，修改后点击“保存设置”", @"Choose an item, edit it, then click “Save”");
    self.engine.manualFeedback = L(@"选择数量后，点击“记入今天”", @"Choose quantities, then click “Add to Today”");
    self.engine.activityLabel = self.engine.active ? L(@"键盘或鼠标", @"Keyboard or mouse") : L(@"已停止计时", @"Timing stopped");
    self.window.title = L(@"工作时钟", @"Work Clock");
    [self setNeedsLayout:YES];
    [self setNeedsDisplay:YES];
}

- (void)layout {
    [super layout];
    CGFloat h = NSHeight(self.bounds), w = NSWidth(self.bounds), margin = 24;
    BOOL overview = self.pageTabs.selectedSegment == 0;
    CGFloat tabsWidth = UseEnglish ? 420 : 330;
    self.pageTabs.frame = NSMakeRect((w - tabsWidth) / 2.0, h - 78, tabsWidth, 30);
    self.periodControl.frame = NSMakeRect(margin + 20, h - 147, 210, 30);
    self.previousPeriodButton.frame = NSMakeRect(w - margin - 322, h - 147, 96, 30);
    self.nextPeriodButton.frame = NSMakeRect(w - margin - 108, h - 147, 96, 30);
    self.currentPeriodButton.frame = NSMakeRect(w - margin - 216, h - 145, 98, 26);
    CGFloat manualY = h - 418;
    CGFloat groupWidth = (w - 2 * margin - 170) / 3.0;
    self.classPopup.frame = NSMakeRect(margin + 20, manualY + 18, 92, 30);
    self.wholePlantPopup.frame = NSMakeRect(margin + 20 + groupWidth, manualY + 18, 92, 30);
    self.organPopup.frame = NSMakeRect(margin + 20 + groupWidth * 2, manualY + 18, 92, 30);
    self.recordButton.frame = NSMakeRect(w - margin - 130, manualY + 18, 110, 32);
    self.settingsTypePopup.frame = NSMakeRect(margin + 22, h - 264, 210, 30);
    self.settingsNameField.frame = NSMakeRect(margin + 266, h - 264, 238, 30);
    self.settingsMinutesField.frame = NSMakeRect(margin + 538, h - 264, 118, 30);
    self.settingsSaveButton.frame = NSMakeRect(w - margin - 142, h - 265, 120, 32);
    self.languageControl.frame = NSMakeRect(margin + 190, 102, 220, 30);
    self.manualButton.frame = NSMakeRect(24, 16, UseEnglish ? 220 : 170, 32);
    self.loginButton.frame = NSMakeRect(overview ? (UseEnglish ? 260 : 215) : 24, 19, 240, 26);
    self.dataButton.frame = NSMakeRect(NSWidth(self.bounds) - (UseEnglish ? 178 : 158), 18, UseEnglish ? 154 : 134, 28);
}

- (void)updateModeControls {
    self.hoveredTarget = nil;
    BOOL overview = self.pageTabs.selectedSegment == 0;
    BOOL statistics = self.pageTabs.selectedSegment == 1;
    BOOL settings = self.pageTabs.selectedSegment == 2;
    self.periodControl.hidden = !statistics;
    self.previousPeriodButton.hidden = !statistics;
    self.nextPeriodButton.hidden = !statistics;
    self.currentPeriodButton.hidden = !statistics;
    self.classPopup.hidden = !overview;
    self.wholePlantPopup.hidden = !overview;
    self.organPopup.hidden = !overview;
    self.recordButton.hidden = !overview;
    self.manualButton.hidden = !overview;
    self.settingsTypePopup.hidden = !settings;
    self.settingsNameField.hidden = !settings;
    self.settingsMinutesField.hidden = !settings;
    self.settingsSaveButton.hidden = !settings;
    self.languageControl.hidden = !settings;
    NSDate *selectedStart = StatisticsPeriodStart(self.statisticsDate, self.statisticsScale);
    NSDate *currentStart = StatisticsPeriodStart([NSDate date], self.statisticsScale);
    self.nextPeriodButton.enabled = [selectedStart compare:currentStart] == NSOrderedAscending;
    self.currentPeriodButton.enabled = [selectedStart compare:currentStart] != NSOrderedSame;
    [self setNeedsLayout:YES];
    [self setNeedsDisplay:YES];
}

- (void)pageChanged:(NSSegmentedControl *)sender { [self updateModeControls]; }
- (void)periodChanged:(NSSegmentedControl *)sender {
    self.statisticsScale = (StatisticsScale)sender.selectedSegment;
    self.statisticsDate = [NSDate date];
    [self updateModeControls];
}
- (void)movePeriod:(NSButton *)sender {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSCalendarUnit unit = self.statisticsScale == StatisticsScaleWeek ? NSCalendarUnitDay
        : (self.statisticsScale == StatisticsScaleMonth ? NSCalendarUnitMonth : NSCalendarUnitYear);
    NSInteger amount = self.statisticsScale == StatisticsScaleWeek ? 7 * sender.tag : sender.tag;
    self.statisticsDate = [calendar dateByAddingUnit:unit value:amount toDate:self.statisticsDate options:0];
    [self updateModeControls];
}
- (void)resetPeriod:(id)sender { self.statisticsDate = [NSDate date]; [self updateModeControls]; }

- (void)languageChanged:(NSSegmentedControl *)sender {
    UseEnglish = sender.selectedSegment == 1;
    [NSUserDefaults.standardUserDefaults setObject:(UseEnglish ? @"en" : @"zh") forKey:@"AppLanguage"];
    [self applyLanguageToControls];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WorkTimeLanguageChanged" object:nil];
}

- (void)loadSelectedSettingsType {
    NSInteger index = MAX(0, MIN(self.settingsTypePopup.indexOfSelectedItem, (NSInteger)self.engine.manualWorkTypes.count - 1));
    if (index >= (NSInteger)self.engine.manualWorkTypes.count) return;
    NSDictionary *definition = self.engine.manualWorkTypes[index];
    self.settingsNameField.stringValue = ManualTypeDisplayName(definition);
    self.settingsMinutesField.stringValue = [definition[@"unitMinutes"] stringValue];
}

- (void)refreshManualTypeControlsKeepingIndex:(NSInteger)selectedIndex {
    [self.settingsTypePopup removeAllItems];
    for (NSDictionary *definition in self.engine.manualWorkTypes) [self.settingsTypePopup addItemWithTitle:ManualTypeDisplayName(definition)];
    [self.settingsTypePopup selectItemAtIndex:MAX(0, MIN(selectedIndex, (NSInteger)self.engine.manualWorkTypes.count - 1))];
    [self loadSelectedSettingsType];
    [self setNeedsDisplay:YES];
}

- (void)settingsTypeChanged:(id)sender {
    self.settingsFeedback = L(@"修改名称或分钟数后，点击“保存设置”", @"Edit the name or minutes, then click “Save”");
    [self loadSelectedSettingsType];
    [self setNeedsDisplay:YES];
}

- (void)saveSettingsType:(id)sender {
    NSString *name = [self.settingsNameField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSScanner *scanner = [NSScanner scannerWithString:self.settingsMinutesField.stringValue];
    NSInteger minutes = 0;
    BOOL validMinutes = [scanner scanInteger:&minutes] && scanner.isAtEnd && minutes >= 1 && minutes <= 1440;
    NSInteger maximumNameLength = UseEnglish ? 24 : 12;
    if (name.length == 0 || (NSInteger)name.length > maximumNameLength) {
        self.settingsFeedback = L(@"名称需要填写，最多 12 个字", @"Enter a name of no more than 24 characters");
        [self setNeedsDisplay:YES];
        return;
    }
    if (!validMinutes) {
        self.settingsFeedback = L(@"每次时长请填写 1－1440 的整数分钟", @"Enter a whole number from 1 to 1440 minutes");
        [self setNeedsDisplay:YES];
        return;
    }
    NSInteger index = self.settingsTypePopup.indexOfSelectedItem;
    if (index < 0 || index >= (NSInteger)self.engine.manualWorkTypes.count) return;
    NSMutableDictionary *definition = self.engine.manualWorkTypes[index];
    definition[@"name"] = name;
    definition[@"unitMinutes"] = @(minutes);
    [self.engine save];
    self.settingsFeedback = [NSString stringWithFormat:L(@"已保存：%@，每次 %@", @"Saved: %@, %@ each"), name, ChineseDuration(minutes * 60)];
    [self refreshManualTypeControlsKeepingIndex:index];
}

- (void)manual:(id)sender { [self.engine beginManualMinute]; [self setNeedsDisplay:YES]; }
- (void)recordManualWork:(id)sender {
    NSTimeInterval recorded = [self.engine recordClasses:self.classPopup.indexOfSelectedItem
        wholePlants:self.wholePlantPopup.indexOfSelectedItem organs:self.organPopup.indexOfSelectedItem];
    if (recorded > 0) {
        [self.classPopup selectItemAtIndex:0];
        [self.wholePlantPopup selectItemAtIndex:0];
        [self.organPopup selectItemAtIndex:0];
    }
    [self setNeedsDisplay:YES];
}
- (void)loginChanged:(NSButton *)sender { [self.engine setLaunchAtLogin:sender.state == NSControlStateValueOn]; sender.state = self.engine.launchAtLogin ? NSControlStateValueOn : NSControlStateValueOff; }
- (void)showData:(id)sender { [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[self.engine.dataFileURL]]; }

- (void)drawProgress:(NSRect)rect value:(double)value {
    FillRounded(rect, 4, [NSColor colorWithWhite:1 alpha:0.08]);
    NSRect fill = rect; fill.size.width *= MIN(MAX(value, 0), 1);
    FillRounded(fill, 4, value >= 1 ? GreenColor() : OrangeColor());
}

- (void)drawMetricCard:(NSRect)rect title:(NSString *)title seconds:(NSTimeInterval)seconds footer:(NSString *)footer achieved:(BOOL)achieved {
    FillRounded(rect, 18, CardColor());
    DrawText(title, NSMakePoint(NSMinX(rect) + 20, NSMaxY(rect) - 36), 14, NSFontWeightRegular, SecondaryTextColor());
    DrawText(ClockText(seconds), NSMakePoint(NSMinX(rect) + 20, NSMaxY(rect) - 100), 46, NSFontWeightBold, PrimaryTextColor());
    [self drawProgress:NSMakeRect(NSMinX(rect) + 20, NSMinY(rect) + 52, NSWidth(rect) - 40, 9) value:seconds / kDailyTarget];
    DrawText(footer, NSMakePoint(NSMinX(rect) + 20, NSMinY(rect) + 20), 13, NSFontWeightSemibold, achieved ? GreenColor() : OrangeColor());
}

- (void)drawWeekPanel:(NSRect)rect {
    FillRounded(rect, 18, CardColor());
    DrawText(L(@"本周", @"This Week"), NSMakePoint(NSMinX(rect) + 20, NSMaxY(rect) - 34), 17, NSFontWeightBold, PrimaryTextColor());
    NSArray *labels = UseEnglish ? @[@"Mon", @"Tue", @"Wed", @"Thu", @"Fri", @"Sat", @"Sun"] : @[@"周一", @"周二", @"周三", @"周四", @"周五", @"周六", @"周日"];
    NSDate *monday = StartOfWeek([NSDate date]);
    NSCalendar *calendar = [NSCalendar currentCalendar];
    CGFloat left = NSMinX(rect) + 24, bottom = NSMinY(rect) + 24;
    CGFloat width = (NSWidth(rect) - 48) / 7.0;
    for (NSInteger i = 0; i < 7; i++) {
        NSDate *date = [calendar dateByAddingUnit:NSCalendarUnitDay value:i toDate:monday options:0];
        BOOL future = [date compare:StartOfDay([NSDate date])] == NSOrderedDescending;
        double seconds = [self.engine.dailySeconds[DateKey(date)] doubleValue];
        CGFloat barHeight = 62 * MIN(seconds / kDailyTarget, 1);
        NSRect track = NSMakeRect(left + i * width + width * 0.30, bottom + 42, width * 0.40, 62);
        FillRounded(track, 6, [NSColor colorWithWhite:1 alpha:0.06]);
        NSRect fill = track; fill.size.height = future ? 0 : barHeight;
        FillRounded(fill, 6, seconds >= kDailyTarget ? GreenColor() : OrangeColor());
        DrawText(future ? @"—" : ClockText(seconds), NSMakePoint(left + i * width + width * 0.22, bottom + 21), 10, NSFontWeightRegular, SecondaryTextColor());
        DrawText(labels[i], NSMakePoint(left + i * width + width * 0.24, bottom), 11, NSFontWeightRegular, SecondaryTextColor());
        NSString *detail = future ? L(@"尚未到达", @"Future date") : [NSString stringWithFormat:L(@"工作 %@", @"Worked %@"), ChineseDuration(seconds)];
        [self addHoverRect:NSMakeRect(left + i * width, bottom, width, 128)
            title:TooltipDateText(date) detail:detail];
    }
}

- (void)drawManualWorkPanel:(NSRect)rect {
    FillRounded(rect, 18, CardColor());
    DrawText(L(@"手动工作记录", @"Manual Work"), NSMakePoint(NSMinX(rect) + 20, NSMaxY(rect) - 32), 17, NSFontWeightBold, PrimaryTextColor());
    DrawText(self.engine.manualFeedback, NSMakePoint(NSMinX(rect) + 174, NSMaxY(rect) - 30), 12, NSFontWeightRegular,
        ([self.engine.manualFeedback hasPrefix:@"已记入"] || [self.engine.manualFeedback hasPrefix:@"Added"]) ? GreenColor() : SecondaryTextColor());
    CGFloat groupWidth = (NSWidth(rect) - 170) / 3.0;
    for (NSInteger index = 0; index < 3; index++) {
        NSDictionary *definition = self.engine.manualWorkTypes[index];
        NSString *label = [NSString stringWithFormat:L(@"%@  ·  %@/次", @"%@  ·  %@ each"), ManualTypeDisplayName(definition), ChineseDuration([definition[@"unitMinutes"] integerValue] * 60)];
        DrawText(label, NSMakePoint(NSMinX(rect) + 20 + groupWidth * index, NSMinY(rect) + 57), 12, NSFontWeightSemibold, PrimaryTextColor());
    }
}

- (void)drawHeatmap:(NSRect)rect {
    FillRounded(rect, 18, CardColor());
    DrawText(L(@"近一年工作热图", @"Work Heatmap · Last 12 Months"), NSMakePoint(NSMinX(rect) + 20, NSMaxY(rect) - 34), 17, NSFontWeightBold, PrimaryTextColor());
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *today = StartOfDay([NSDate date]);
    NSDate *candidate = [calendar dateByAddingUnit:NSCalendarUnitDay value:-363 toDate:today options:0];
    NSDate *start = StartOfWeek(candidate);
    CGFloat gap = 3, originX = NSMinX(rect) + 20, originY = NSMinY(rect) + 27;
    CGFloat cell = MIN((NSWidth(rect) - 40 - gap * 52) / 53.0, 12);
    for (NSInteger offset = 0; offset < 53 * 7; offset++) {
        NSDate *date = [calendar dateByAddingUnit:NSCalendarUnitDay value:offset toDate:start options:0];
        if ([date compare:today] == NSOrderedDescending) continue;
        NSInteger column = offset / 7, row = offset % 7;
        NSRect cellRect = NSMakeRect(originX + column * (cell + gap), originY + (6 - row) * (cell + gap), cell, cell);
        NSTimeInterval seconds = [self.engine.dailySeconds[DateKey(date)] doubleValue];
        FillRounded(cellRect, 2.2, HeatColor(seconds));
        [self addHoverRect:cellRect title:TooltipDateText(date)
            detail:[NSString stringWithFormat:L(@"工作 %@", @"Worked %@"), ChineseDuration(seconds)]];
    }
    for (NSDictionary *mark in HeatmapMonthMarks(start, today)) {
        NSInteger column = [mark[@"column"] integerValue];
        CGFloat labelX = originX + column * (cell + gap);
        DrawText(mark[@"label"], NSMakePoint(labelX, NSMinY(rect) + 7), 11, NSFontWeightRegular, SecondaryTextColor());
    }
    NSArray<NSNumber *> *legendValues = @[@(10 * 60), @(35 * 60), @(75 * 60), @(150 * 60), @(300 * 60), @(600 * 60)];
    CGFloat legendX = NSMaxX(rect) - 174, legendY = NSMaxY(rect) - 31;
    DrawText(L(@"少", @"Less"), NSMakePoint(legendX - (UseEnglish ? 12 : 0), legendY - 1), 10, NSFontWeightRegular, SecondaryTextColor());
    for (NSInteger index = 0; index < (NSInteger)legendValues.count; index++) {
        FillRounded(NSMakeRect(legendX + 25 + index * 16, legendY, 11, 11), 2.2, HeatColor(legendValues[index].doubleValue));
    }
    DrawText(L(@"多", @"More"), NSMakePoint(legendX + 126, legendY - 1), 10, NSFontWeightRegular, SecondaryTextColor());
}

- (void)drawStatisticsSummary:(NSRect)rect totals:(NSDictionary<NSString *, NSNumber *> *)totals start:(NSDate *)start end:(NSDate *)end {
    FillRounded(rect, 18, CardColor());
    DrawText(L(@"所选周期总工作", @"Total Work in Period"), NSMakePoint(NSMinX(rect) + 22, NSMaxY(rect) - 38), 15, NSFontWeightSemibold, SecondaryTextColor());
    NSTimeInterval total = [totals[@"total"] doubleValue];
    DrawText(ClockText(total), NSMakePoint(NSMinX(rect) + 22, NSMinY(rect) + 38), 52, NSFontWeightBold, PrimaryTextColor());

    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *tomorrow = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:StartOfDay([NSDate date]) options:0];
    NSDate *effectiveEnd = [end compare:tomorrow] == NSOrderedDescending ? tomorrow : end;
    NSInteger days = MAX(1, [[calendar components:NSCalendarUnitDay fromDate:start toDate:effectiveEnd options:0] day]);
    NSTimeInterval average = total / days;
    CGFloat dividerX = NSMidX(rect) + 38;
    [[NSColor colorWithWhite:1 alpha:0.09] setFill]; NSRectFill(NSMakeRect(dividerX, NSMinY(rect) + 24, 1, NSHeight(rect) - 48));
    DrawText(L(@"日均工作", @"Daily Average"), NSMakePoint(dividerX + 28, NSMaxY(rect) - 38), 15, NSFontWeightSemibold, SecondaryTextColor());
    DrawText(ClockText(average), NSMakePoint(dividerX + 28, NSMinY(rect) + 52), 34, NSFontWeightBold, PrimaryTextColor());
    DrawText([NSString stringWithFormat:L(@"按已覆盖的 %ld 天计算", @"Based on %ld covered days"), (long)days], NSMakePoint(dividerX + 28, NSMinY(rect) + 28), 12, NSFontWeightRegular, SecondaryTextColor());
}

- (void)drawCategoryPanel:(NSRect)rect totals:(NSDictionary<NSString *, NSNumber *> *)totals {
    FillRounded(rect, 18, CardColor());
    DrawText(L(@"不同工作类型", @"Work by Type"), NSMakePoint(NSMinX(rect) + 20, NSMaxY(rect) - 34), 17, NSFontWeightBold, PrimaryTextColor());
    DrawText(L(@"各类型相加等于所选周期总时长", @"All types add up to the period total"), NSMakePoint(NSMinX(rect) + (UseEnglish ? 142 : 164), NSMaxY(rect) - 31), 12, NSFontWeightRegular, SecondaryTextColor());
    NSArray<NSColor *> *colors = @[OrangeColor(), BlueColor(), PurpleColor()];
    NSMutableArray<NSDictionary *> *items = [NSMutableArray arrayWithObject:@{@"label": L(@"电脑工作", @"Computer Work"), @"key": @"computer", @"color": GreenColor()}];
    for (NSInteger index = 0; index < 3; index++) {
        NSDictionary *definition = self.engine.manualWorkTypes[index];
        [items addObject:@{@"label": ManualTypeDisplayName(definition), @"key": definition[@"id"], @"color": colors[index]}];
    }
    double total = [totals[@"total"] doubleValue];
    CGFloat rowTop = NSMaxY(rect) - 70;
    for (NSInteger index = 0; index < (NSInteger)items.count; index++) {
        NSDictionary *item = items[index];
        double seconds = [totals[item[@"key"]] doubleValue];
        double share = total > 0 ? seconds / total : 0;
        CGFloat y = rowTop - index * 42;
        NSColor *color = item[@"color"];
        [color setFill]; [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(NSMinX(rect) + 20, y + 2, 9, 9)] fill];
        DrawText(item[@"label"], NSMakePoint(NSMinX(rect) + 38, y - 1), 13, NSFontWeightSemibold, PrimaryTextColor());
        CGFloat trackOffset = UseEnglish ? 250 : 180;
        NSRect track = NSMakeRect(NSMinX(rect) + trackOffset, y + 2, NSWidth(rect) - trackOffset - 230, 9);
        FillRounded(track, 4, [NSColor colorWithWhite:1 alpha:0.08]);
        NSRect fill = track; fill.size.width *= share; FillRounded(fill, 4, color);
        DrawText(ChineseDuration(seconds), NSMakePoint(NSMaxX(rect) - 210, y - 1), 13, NSFontWeightSemibold, PrimaryTextColor());
        DrawText([NSString stringWithFormat:@"%ld%%", (long)llround(share * 100)], NSMakePoint(NSMaxX(rect) - 72, y - 1), 12, NSFontWeightRegular, SecondaryTextColor());
    }
}

- (NSArray<NSDictionary *> *)trendBinsFrom:(NSDate *)start end:(NSDate *)end {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSMutableArray<NSDictionary *> *bins = [NSMutableArray array];
    NSInteger count;
    NSCalendarUnit unit;
    if (self.statisticsScale == StatisticsScaleYear) {
        count = 12; unit = NSCalendarUnitMonth;
    } else {
        count = [[calendar components:NSCalendarUnitDay fromDate:start toDate:end options:0] day];
        unit = NSCalendarUnitDay;
    }
    NSArray *weekLabels = UseEnglish ? @[@"Mon", @"Tue", @"Wed", @"Thu", @"Fri", @"Sat", @"Sun"] : @[@"周一", @"周二", @"周三", @"周四", @"周五", @"周六", @"周日"];
    for (NSInteger index = 0; index < count; index++) {
        NSDate *binStart = [calendar dateByAddingUnit:unit value:index toDate:start options:0];
        NSDate *binEnd = [calendar dateByAddingUnit:unit value:1 toDate:binStart options:0];
        double seconds = 0;
        for (NSString *key in self.engine.dailySeconds) {
            if (DateKeyIsInRange(key, binStart, binEnd)) seconds += [self.engine.dailySeconds[key] doubleValue];
        }
        NSString *label;
        if (self.statisticsScale == StatisticsScaleWeek) label = weekLabels[index];
        else if (self.statisticsScale == StatisticsScaleYear) label = UseEnglish ? [NSString stringWithFormat:@"%ld", (long)(index + 1)] : [NSString stringWithFormat:@"%ld月", (long)(index + 1)];
        else label = [NSString stringWithFormat:@"%ld", (long)(index + 1)];
        [bins addObject:@{@"seconds": @(seconds), @"label": label, @"date": binStart}];
    }
    return bins;
}

- (void)drawTrendPanel:(NSRect)rect start:(NSDate *)start end:(NSDate *)end {
    FillRounded(rect, 18, CardColor());
    NSString *grain = self.statisticsScale == StatisticsScaleYear ? L(@"按月", @"Monthly") : L(@"按天", @"Daily");
    DrawText([NSString stringWithFormat:L(@"周期内工作分布 · %@", @"Work Distribution · %@"), grain], NSMakePoint(NSMinX(rect) + 20, NSMaxY(rect) - 34), 17, NSFontWeightBold, PrimaryTextColor());
    NSArray<NSDictionary *> *bins = [self trendBinsFrom:start end:end];
    double maximum = self.statisticsScale == StatisticsScaleYear ? 30 * kDailyTarget : kDailyTarget;
    for (NSDictionary *bin in bins) maximum = MAX(maximum, [bin[@"seconds"] doubleValue]);
    CGFloat left = NSMinX(rect) + 24, bottom = NSMinY(rect) + 24;
    CGFloat slot = (NSWidth(rect) - 48) / MAX((NSInteger)bins.count, 1);
    CGFloat chartHeight = NSHeight(rect) - 86;
    for (NSInteger index = 0; index < (NSInteger)bins.count; index++) {
        NSDictionary *bin = bins[index];
        double seconds = [bin[@"seconds"] doubleValue];
        CGFloat barWidth = MAX(4, MIN(28, slot * 0.52));
        NSRect track = NSMakeRect(left + index * slot + (slot - barWidth) / 2, bottom + 24, barWidth, chartHeight);
        FillRounded(track, MIN(5, barWidth / 2), [NSColor colorWithWhite:1 alpha:0.06]);
        NSRect fill = track; fill.size.height = chartHeight * (seconds / maximum);
        FillRounded(fill, MIN(5, barWidth / 2), seconds >= kDailyTarget ? GreenColor() : OrangeColor());
        BOOL showLabel = self.statisticsScale != StatisticsScaleMonth || index == 0 || (index + 1) % 5 == 0 || index == (NSInteger)bins.count - 1;
        if (showLabel) DrawText(bin[@"label"], NSMakePoint(left + index * slot + slot * 0.22, bottom), 10, NSFontWeightRegular, SecondaryTextColor());
        if (bins.count <= 12) DrawText(ClockText(seconds), NSMakePoint(left + index * slot + slot * 0.16, NSMaxY(rect) - 56), 9, NSFontWeightRegular, SecondaryTextColor());
        NSString *hoverTitle;
        if (self.statisticsScale == StatisticsScaleYear) {
            NSDateComponents *parts = [[NSCalendar currentCalendar] components:(NSCalendarUnitYear | NSCalendarUnitMonth) fromDate:bin[@"date"]];
            hoverTitle = UseEnglish
                ? [NSString stringWithFormat:@"%ld-%02ld", (long)parts.year, (long)parts.month]
                : [NSString stringWithFormat:@"%ld年%ld月", (long)parts.year, (long)parts.month];
        } else hoverTitle = TooltipDateText(bin[@"date"]);
        [self addHoverRect:NSMakeRect(left + index * slot, bottom, slot, chartHeight + 48)
            title:hoverTitle detail:[NSString stringWithFormat:L(@"工作 %@", @"Worked %@"), ChineseDuration(seconds)]];
    }
}

- (void)drawStatisticsPageWithWidth:(CGFloat)w height:(CGFloat)h margin:(CGFloat)margin {
    CGFloat contentW = w - 2 * margin;
    NSRect filterRect = NSMakeRect(margin, h - 174, contentW, 74);
    FillRounded(filterRect, 18, CardColor());
    DrawText(StatisticsPeriodLabel(self.statisticsDate, self.statisticsScale), NSMakePoint(NSMinX(filterRect) + 264, NSMinY(filterRect) + 24), 17, NSFontWeightBold, PrimaryTextColor());

    NSDate *start = StatisticsPeriodStart(self.statisticsDate, self.statisticsScale);
    NSDate *end = StatisticsPeriodEnd(self.statisticsDate, self.statisticsScale);
    NSDictionary *totals = [self.engine statisticsFrom:start to:end];
    [self drawStatisticsSummary:NSMakeRect(margin, h - 344, contentW, 154) totals:totals start:start end:end];
    [self drawCategoryPanel:NSMakeRect(margin, h - 580, contentW, 220) totals:totals];
    [self drawTrendPanel:NSMakeRect(margin, 62, contentW, h - 658) start:start end:end];
}

- (void)drawSettingsPageWithWidth:(CGFloat)w height:(CGFloat)h margin:(CGFloat)margin {
    CGFloat contentW = w - 2 * margin;
    NSRect editRect = NSMakeRect(margin, h - 340, contentW, 240);
    FillRounded(editRect, 18, CardColor());
    DrawText(L(@"手动工作类型设置", @"Manual Work Types"), NSMakePoint(NSMinX(editRect) + 22, NSMaxY(editRect) - 40), 18, NSFontWeightBold, PrimaryTextColor());
    DrawText(L(@"每个项目都统一设置一个名称，以及每完成一次应计入的时间。", @"Give each item a name and set the time credited for each completion."), NSMakePoint(NSMinX(editRect) + 22, NSMaxY(editRect) - 66), 13, NSFontWeightRegular, SecondaryTextColor());
    DrawText(L(@"选择项目", @"Select Item"), NSMakePoint(NSMinX(editRect) + 22, NSMaxY(editRect) - 116), 12, NSFontWeightSemibold, SecondaryTextColor());
    DrawText(L(@"工作名称", @"Work Name"), NSMakePoint(NSMinX(editRect) + 266, NSMaxY(editRect) - 116), 12, NSFontWeightSemibold, SecondaryTextColor());
    DrawText(L(@"每次计入（分钟）", @"Minutes Each"), NSMakePoint(NSMinX(editRect) + 538, NSMaxY(editRect) - 116), 12, NSFontWeightSemibold, SecondaryTextColor());
    BOOL saved = [self.settingsFeedback hasPrefix:@"已保存"] || [self.settingsFeedback hasPrefix:@"Saved"];
    BOOL error = [self.settingsFeedback hasPrefix:@"名称"] || [self.settingsFeedback hasPrefix:@"每次"] || [self.settingsFeedback hasPrefix:@"Enter"];
    DrawText(self.settingsFeedback, NSMakePoint(NSMinX(editRect) + 22, NSMinY(editRect) + 28), 13, NSFontWeightSemibold,
        saved ? GreenColor() : (error ? OrangeColor() : SecondaryTextColor()));

    NSRect listRect = NSMakeRect(margin, h - 646, contentW, 286);
    FillRounded(listRect, 18, CardColor());
    DrawText(L(@"当前三个项目", @"Current Three Items"), NSMakePoint(NSMinX(listRect) + 22, NSMaxY(listRect) - 40), 18, NSFontWeightBold, PrimaryTextColor());
    for (NSInteger index = 0; index < 3; index++) {
        NSDictionary *definition = self.engine.manualWorkTypes[index];
        CGFloat y = NSMaxY(listRect) - 92 - index * 54;
        FillRounded(NSMakeRect(NSMinX(listRect) + 22, y - 10, 30, 30), 8, [NSColor colorWithWhite:1 alpha:0.07]);
        DrawText([NSString stringWithFormat:@"%ld", (long)(index + 1)], NSMakePoint(NSMinX(listRect) + 33, y - 3), 13, NSFontWeightBold, SecondaryTextColor());
        DrawText(ManualTypeDisplayName(definition), NSMakePoint(NSMinX(listRect) + 70, y), 15, NSFontWeightSemibold, PrimaryTextColor());
        DrawText([NSString stringWithFormat:L(@"每次计入 %@", @"%@ each"), ChineseDuration([definition[@"unitMinutes"] integerValue] * 60)],
            NSMakePoint(NSMinX(listRect) + 330, y), 14, NSFontWeightSemibold, GreenColor());
    }
    DrawText(L(@"修改名称会同步用于手动记录和分类统计；已经记录的历史时长不会重新计算。", @"Name changes apply to manual entry and statistics. Recorded history is never recalculated."),
        NSMakePoint(NSMinX(listRect) + 22, NSMinY(listRect) + 24), 12, NSFontWeightRegular, SecondaryTextColor());

    NSRect languageRect = NSMakeRect(margin, 70, contentW, 100);
    FillRounded(languageRect, 18, CardColor());
    DrawText(L(@"界面语言", @"Interface Language"), NSMakePoint(NSMinX(languageRect) + 22, NSMidY(languageRect) - 6), 16, NSFontWeightBold, PrimaryTextColor());
    DrawText(L(@"选择中文或英文，切换后立即生效。", @"Choose Chinese or English. Changes apply immediately."), NSMakePoint(NSMinX(languageRect) + 430, NSMidY(languageRect) - 5), 12, NSFontWeightRegular, SecondaryTextColor());
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    [self.hoverTargets removeAllObjects];
    [PanelColor() setFill]; NSRectFill(self.bounds);
    CGFloat w = NSWidth(self.bounds), h = NSHeight(self.bounds);
    CGFloat margin = 24, contentW = w - 2 * margin;

    BOOL statistics = self.pageTabs.selectedSegment == 1;
    BOOL settings = self.pageTabs.selectedSegment == 2;
    DrawText(L(@"工作时钟", @"Work Clock"), NSMakePoint(margin, h - 53), 28, NSFontWeightBold, PrimaryTextColor());
    NSString *subtitle = statistics
        ? L(@"按工作类型查看周、月、年", @"View work by type, week, month, or year")
        : (settings ? L(@"设置工作名称和每次计入时长", @"Set work names, durations, and language") : L(@"只计算您的主动操作", @"Counts only your active input"));
    DrawText(subtitle, NSMakePoint(margin, h - 75), 13, NSFontWeightRegular, SecondaryTextColor());
    NSColor *dot = self.engine.active ? GreenColor() : [NSColor colorWithWhite:0.5 alpha:0.5];
    [dot setFill]; [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(w - 220, h - 54, 9, 9)] fill];
    DrawText(self.engine.active ? L(@"正在计时", @"Timing") : L(@"现在未计时", @"Not Timing"), NSMakePoint(w - 198, h - 60), 14, NSFontWeightSemibold, PrimaryTextColor());
    DrawText(self.engine.activityLabel, NSMakePoint(w - 198, h - 77), 11, NSFontWeightRegular, SecondaryTextColor());

    if (statistics) {
        [self drawStatisticsPageWithWidth:w height:h margin:margin];
        [self drawHoverTooltip];
        return;
    }
    if (settings) {
        [self drawSettingsPageWithWidth:w height:h margin:margin];
        return;
    }

    CGFloat cardY = h - 278, gap = 16, cardW = (contentW - gap) / 2;
    NSTimeInterval today = self.engine.todaySeconds;
    NSString *todayFooter = today >= kDailyTarget ? L(@"今日已达标", @"Today's target reached") : [NSString stringWithFormat:L(@"距 10 小时还差 %@", @"%@ remaining to 10 hours"), ChineseDuration(kDailyTarget - today)];
    [self drawMetricCard:NSMakeRect(margin, cardY, cardW, 178) title:L(@"今日工作", @"Today") seconds:today footer:todayFooter achieved:today >= kDailyTarget];
    NSTimeInterval average = self.engine.weeklyAverage;
    NSString *averageFooter = average >= kDailyTarget ? L(@"已达到日均 10 小时", @"10-hour daily average reached") : L(@"目标：每天平均 10 小时", @"Goal: average 10 hours a day");
    [self drawMetricCard:NSMakeRect(margin + cardW + gap, cardY, cardW, 178) title:L(@"本周日均（周一至今天）", @"Weekly Daily Average") seconds:average footer:averageFooter achieved:average >= kDailyTarget];

    CGFloat manualY = cardY - 140;
    [self drawManualWorkPanel:NSMakeRect(margin, manualY, contentW, 120)];
    CGFloat weekY = manualY - 184;
    [self drawWeekPanel:NSMakeRect(margin, weekY, contentW, 164)];
    [self drawHeatmap:NSMakeRect(margin, 62, contentW, weekY - 82)];
    [self drawHoverTooltip];
}
@end

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property WorkTimeEngine *engine;
@property NSWindow *window;
@property NSStatusItem *statusItem;
@property NSTimer *statusTimer;
@end

@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    UseEnglish = [[defaults stringForKey:@"AppLanguage"] isEqual:@"en"];
    self.engine = [WorkTimeEngine new];
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 900, 850)
        styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable | NSWindowStyleMaskFullSizeContentView)
        backing:NSBackingStoreBuffered defer:NO];
    self.window.title = L(@"工作时钟", @"Work Clock");
    self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    self.window.titlebarAppearsTransparent = YES;
    self.window.releasedWhenClosed = NO;
    self.window.minSize = NSMakeSize(820, 850);
    self.window.delegate = self;
    self.window.contentView = [[DashboardView alloc] initWithFrame:self.window.contentView.bounds engine:self.engine];
    [self.window center];

    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.image = [NSImage imageWithSystemSymbolName:@"timer" accessibilityDescription:L(@"工作时钟", @"Work Clock")];
    self.statusItem.button.imagePosition = NSImageLeading;
    self.statusItem.button.target = self;
    self.statusItem.button.action = @selector(statusClicked:);
    [self.statusItem.button sendActionOn:(NSEventMaskLeftMouseUp | NSEventMaskRightMouseUp)];

    [self.engine start];
    [self updateStatus];
    __weak typeof(self) weakSelf = self;
    self.statusTimer = [NSTimer timerWithTimeInterval:10 repeats:YES block:^(__unused NSTimer *timer) { [weakSelf updateStatus]; }];
    [[NSRunLoop mainRunLoop] addTimer:self.statusTimer forMode:NSRunLoopCommonModes];
    [[NSNotificationCenter defaultCenter] addObserverForName:@"WorkTimeLanguageChanged" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
        [weakSelf updateStatus];
    }];

    if ([defaults objectForKey:@"AutoLaunchDesired"] == nil) [defaults setBool:YES forKey:@"AutoLaunchDesired"];
    if ([defaults boolForKey:@"AutoLaunchDesired"]) [self.engine setLaunchAtLogin:YES];
    [defaults setBool:YES forKey:@"HasShownDashboard"];
    if (!LaunchedInBackground) dispatch_async(dispatch_get_main_queue(), ^{ [self showWindow]; });
}

- (void)applicationWillTerminate:(NSNotification *)notification { [self.statusTimer invalidate]; [self.engine stop]; }
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return NO; }
- (BOOL)windowShouldClose:(NSWindow *)sender { [sender orderOut:nil]; return NO; }
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag { [self showWindow]; return YES; }

- (void)updateStatus {
    self.window.title = L(@"工作时钟", @"Work Clock");
    self.statusItem.button.title = [NSString stringWithFormat:L(@"  今日 %@", @"  Today %@"), ClockText(self.engine.todaySeconds)];
    self.statusItem.button.toolTip = L(@"点击查看工作时间", @"Click to view work time");
}

- (void)showWindow {
    [NSApp activateIgnoringOtherApps:YES];
    [self.window makeKeyAndOrderFront:nil];
}

- (void)statusClicked:(id)sender {
    if (NSApp.currentEvent.type == NSEventTypeRightMouseUp) {
        NSMenu *menu = [NSMenu new];
        NSMenuItem *open = [[NSMenuItem alloc] initWithTitle:L(@"打开工作时钟", @"Open Work Clock") action:@selector(showWindow) keyEquivalent:@""]; open.target = self; [menu addItem:open];
        NSMenuItem *minute = [[NSMenuItem alloc] initWithTitle:L(@"开始 / 续算 2 分钟", @"Start / Continue for 2 Minutes") action:@selector(manualMinute) keyEquivalent:@""]; minute.target = self; [menu addItem:minute];
        [menu addItem:NSMenuItem.separatorItem];
        NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:L(@"退出", @"Quit") action:@selector(quit) keyEquivalent:@"q"]; quit.target = self; [menu addItem:quit];
        [self.statusItem popUpStatusItemMenu:menu];
    } else [self showWindow];
}

- (void)manualMinute { [self.engine beginManualMinute]; [self updateStatus]; }
- (void)quit { [NSApp terminate:nil]; }
@end

static int RunSelfTests(void) {
    UseEnglish = NO;
    NSDateComponents *parts = [NSDateComponents new]; parts.year = 2026; parts.month = 10; parts.day = 24; parts.hour = 12;
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    calendar.timeZone = [NSTimeZone timeZoneWithName:@"Asia/Shanghai"];
    NSDate *date = [calendar dateFromComponents:parts];
    if (![DateKey(date) hasPrefix:@"2026-10-24"]) return 1;
    if (ElapsedWeekDates(date).count != 6) return 2;
    if (![ClockText(36600) isEqual:@"10:10"]) return 3;
    if (ManualWorkSeconds(2, 1, 3) != 21600) return 4;
    if (ManualWorkSeconds(-1, 0, 0) != 0) return 5;
    NSDateComponents *startParts = [NSDateComponents new]; startParts.year = 2025; startParts.month = 10; startParts.day = 20; startParts.hour = 12;
    NSDate *heatmapStart = [calendar dateFromComponents:startParts];
    NSArray<NSDictionary *> *monthMarks = HeatmapMonthMarks(heatmapStart, date);
    if (monthMarks.count != 12) return 6;
    if (![monthMarks.firstObject[@"label"] isEqual:@"11月"] || ![monthMarks.lastObject[@"label"] isEqual:@"10月"]) return 7;
    if (kIdleWindow != 120.0) return 8;
    if (![StatisticsPeriodLabel(date, StatisticsScaleWeek) isEqual:@"2026年10月19日－10月25日"]) return 9;
    if (![StatisticsPeriodLabel(date, StatisticsScaleMonth) isEqual:@"2026年10月"]) return 10;
    if (![StatisticsPeriodLabel(date, StatisticsScaleYear) isEqual:@"2026年"]) return 11;
    NSDictionary *testDaily = @{@"2026-10-24": @18900};
    NSDictionary *testComputer = @{@"2026-10-24": @3600};
    NSArray *testManual = @[
        @{@"date": @"2026-10-24", @"type": @"class", @"totalSeconds": @2700},
        @{@"date": @"2026-10-24", @"type": @"whole_plant_photo", @"totalSeconds": @10800},
        @{@"date": @"2026-10-24", @"type": @"organ_photo", @"totalSeconds": @1800}
    ];
    NSDictionary *testTotals = AggregateCategoryTotals(testDaily, testComputer, testManual,
        StatisticsPeriodStart(date, StatisticsScaleWeek), StatisticsPeriodEnd(date, StatisticsScaleWeek));
    if ([testTotals[@"total"] integerValue] != 18900) return 12;
    if ([testTotals[@"computer"] integerValue] != 3600 || [testTotals[@"class"] integerValue] != 2700) return 13;
    if ([HeatColor(36 * 60) isEqual:HeatColor(98 * 60)]) return 14;
    NSArray *customTypes = @[
        @{@"unitMinutes": @10}, @{@"unitMinutes": @20}, @{@"unitMinutes": @30}
    ];
    if (ConfiguredManualSeconds(customTypes, @[@1, @2, @3]) != 8400) return 15;
    UseEnglish = YES;
    if (![ChineseDuration(3660) isEqual:@"1 hr 1 min"]) return 16;
    if (![StatisticsPeriodLabel(date, StatisticsScaleMonth) isEqual:@"2026-10"]) return 17;
    if (![ManualTypeDisplayName(DefaultManualWorkTypes()[0]) isEqual:@"Teaching"]) return 18;
    if (![ManualTypeDisplayName(DefaultManualWorkTypes()[1]) isEqual:@"Whole Plant Photo"]) return 19;
    UseEnglish = NO;
    puts("ALL_LOGIC_TESTS_PASSED");
    return 0;
}

static AppDelegate *StrongAppDelegate;

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc > 1 && strcmp(argv[1], "--self-test") == 0) return RunSelfTests();
        for (int index = 1; index < argc; index++) if (strcmp(argv[index], "--background") == 0) LaunchedInBackground = YES;
        for (NSRunningApplication *running in [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.jianhe.worktime"]) {
            if (running.processIdentifier != getpid()) {
                [running activateWithOptions:NSApplicationActivateIgnoringOtherApps];
                return 0;
            }
        }
        NSApplication *app = NSApplication.sharedApplication;
        StrongAppDelegate = [AppDelegate new];
        app.delegate = StrongAppDelegate;
        [app run];
    }
    return 0;
}
