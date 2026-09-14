#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

extern "C" __attribute__((visibility("default")))
unsigned long long PuppetUICapture(int requestedMaxNodes, int requestedMaxDepth, unsigned long long requestedMaxBytes, const char *captureID, const char *timestamp) {
if (!captureID || !timestamp || requestedMaxNodes < 1 || requestedMaxNodes > 10000 || requestedMaxDepth < 0 || requestedMaxDepth > 100 || requestedMaxBytes < 65536 || requestedMaxBytes > 33554432) return 0;
return ({
    char *result = (char *)0;
    if ([NSThread isMainThread]) {
      @autoreleasepool {
        NSInteger maxNodes = requestedMaxNodes, maxDepth = requestedMaxDepth;
        NSUInteger maxBytes = requestedMaxBytes;
        id (^num)(double) = ^id(double x) { return isfinite(x) ? @(x) : (id)[NSNull null]; };
        NSDictionary *(^point)(CGPoint) = ^NSDictionary *(CGPoint p) { return @{ @"x":num(p.x), @"y":num(p.y) }; };
        NSDictionary *(^size)(CGSize) = ^NSDictionary *(CGSize s) { return @{ @"width":num(s.width), @"height":num(s.height) }; };
        NSDictionary *(^rect)(CGRect) = ^NSDictionary *(CGRect r) {
          if (CGRectIsInfinite(r) || CGRectIsNull(r)) return @{ @"x":[NSNull null], @"y":[NSNull null], @"width":[NSNull null], @"height":[NSNull null], @"finite":@NO, @"specialValue":CGRectIsInfinite(r) ? @"CGRectInfinite" : @"CGRectNull" };
          return @{ @"x":num(r.origin.x), @"y":num(r.origin.y), @"width":num(r.size.width), @"height":num(r.size.height), @"finite":@(isfinite(r.origin.x)&&isfinite(r.origin.y)&&isfinite(r.size.width)&&isfinite(r.size.height)) };
        };
        NSDictionary *(^insets)(UIEdgeInsets) = ^NSDictionary *(UIEdgeInsets i) { return @{ @"top":num(i.top), @"left":num(i.left), @"bottom":num(i.bottom), @"right":num(i.right) }; };
        NSString *(^ident)(id) = ^NSString *(id x) { return x ? [NSString stringWithFormat:@"v:%p", x] : @""; };
        NSDictionary *(^color)(UIColor *, UITraitCollection *) = ^NSDictionary *(UIColor *c, UITraitCollection *traits) {
          if (!c) return @{ @"available":@NO, @"reason":@"nil" };
          UIColor *resolved = [c resolvedColorWithTraitCollection:traits];
          CGFloat r=0,g=0,b=0,a=0,w=0;
          if ([resolved getRed:&r green:&g blue:&b alpha:&a]) return @{ @"available":@YES, @"space":@"resolved-rgb", @"r":num(r), @"g":num(g), @"b":num(b), @"a":num(a) };
          if ([resolved getWhite:&w alpha:&a]) return @{ @"available":@YES, @"space":@"resolved-gray", @"white":num(w), @"a":num(a) };
          return @{ @"available":@NO, @"reason":@"non-component-color-or-pattern" };
        };
        NSDictionary *(^item)(id) = ^NSDictionary *(id obj) {
          NSObject *x=(NSObject *)obj;
          if (!x) return @{ @"kind":@"none" };
          if ([x isKindOfClass:[UIView class]]) return @{ @"kind":@"view", @"id":ident(x), @"class":NSStringFromClass([x class]) };
          if ([x isKindOfClass:[UILayoutGuide class]]) {
            UILayoutGuide *g=(UILayoutGuide *)x;
            return @{ @"kind":@"layoutGuide", @"id":[NSString stringWithFormat:@"g:%p",g], @"identifier":g.identifier ?: @"", @"owningViewId":ident(g.owningView), @"layoutFrame":rect(g.layoutFrame) };
          }
          return @{ @"kind":@"other", @"class":NSStringFromClass([x class]), @"id":[NSString stringWithFormat:@"o:%p",x] };
        };
        NSDictionary *(^constraint)(NSLayoutConstraint *) = ^NSDictionary *(NSLayoutConstraint *c) {
          return @{ @"id":[NSString stringWithFormat:@"c:%p",c], @"identifier":c.identifier ?: @"", @"firstItem":item(c.firstItem), @"secondItem":item(c.secondItem), @"firstAttribute":@(c.firstAttribute), @"secondAttribute":@(c.secondAttribute), @"relation":@(c.relation), @"multiplier":num(c.multiplier), @"constant":num(c.constant), @"priority":num(c.priority), @"active":@(c.active) };
        };
        NSArray *(^constraints)(NSArray *, NSUInteger) = ^NSArray *(NSArray *list, NSUInteger limit) {
          NSMutableArray *out=[NSMutableArray array];
          for (NSLayoutConstraint *c in list) { if(out.count>=limit) break; [out addObject:constraint(c)]; }
          return out;
        };
        NSMutableArray *windows=[NSMutableArray array], *windowInfo=[NSMutableArray array];
        UIApplication *app=[UIApplication sharedApplication];
        for (UIScene *scene in app.connectedScenes) {
          if (![scene isKindOfClass:[UIWindowScene class]]) continue;
          UIWindowScene *ws=(UIWindowScene *)scene;
          for (UIWindow *w in ws.windows) {
            if ([windows containsObject:w]) continue;
            [windows addObject:w];
            [windowInfo addObject:@{ @"id":ident(w), @"screenBounds":rect(w.screen.bounds), @"screenScale":num(w.screen.scale), @"screenNativeScale":num(w.screen.nativeScale), @"orientation":@(ws.interfaceOrientation), @"sceneActivationState":@(scene.activationState), @"keyWindow":@(w.isKeyWindow), @"windowLevel":num(w.windowLevel) }];
          }
        }
        // Legacy applications may not use UIScene. This is a public deprecated fallback.
        if (windows.count==0) {
          for (UIWindow *w in app.windows) {
            [windows addObject:w];
            [windowInfo addObject:@{ @"id":ident(w), @"screenBounds":rect(w.screen.bounds), @"screenScale":num(w.screen.scale), @"screenNativeScale":num(w.screen.nativeScale), @"orientation":@0, @"sceneActivationState":@0, @"keyWindow":@(w.isKeyWindow), @"windowLevel":num(w.windowLevel) }];
          }
        }
        NSMutableArray *nodes=[NSMutableArray array], *queue=[NSMutableArray array];
        for (UIWindow *w in windows) [queue addObject:@{ @"view":w, @"window":w, @"depth":@0, @"parent":@"", @"ancestorHidden":@NO, @"ancestorAlpha":@1 }];
        BOOL nodeLimit=NO, depthLimit=NO, constraintLimit=NO;
        NSUInteger cursor=0;
        while (cursor<queue.count) {
          if (nodes.count >= (NSUInteger)maxNodes) { nodeLimit=YES; break; }
          NSDictionary *entry=queue[cursor++]; UIView *v=entry[@"view"]; UIWindow *w=entry[@"window"]; NSInteger depth=[(NSNumber *)entry[@"depth"] integerValue];
          CGRect b=v.bounds; CGAffineTransform t=v.transform;
          CGRect sf=[v convertRect:b toCoordinateSpace:w.screen.coordinateSpace];
          NSArray *quad=@[point([v convertPoint:CGPointMake(CGRectGetMinX(b),CGRectGetMinY(b)) toCoordinateSpace:w.screen.coordinateSpace]),point([v convertPoint:CGPointMake(CGRectGetMaxX(b),CGRectGetMinY(b)) toCoordinateSpace:w.screen.coordinateSpace]),point([v convertPoint:CGPointMake(CGRectGetMaxX(b),CGRectGetMaxY(b)) toCoordinateSpace:w.screen.coordinateSpace]),point([v convertPoint:CGPointMake(CGRectGetMinX(b),CGRectGetMaxY(b)) toCoordinateSpace:w.screen.coordinateSpace])];
          BOOL usableScreenRect = !CGRectIsInfinite(sf) && !CGRectIsNull(sf) && isfinite(sf.origin.x) && isfinite(sf.origin.y) && isfinite(sf.size.width) && isfinite(sf.size.height);
          if (!usableScreenRect) {
            NSDictionary *unknownPoint=@{ @"x":[NSNull null], @"y":[NSNull null] };
            quad=@[unknownPoint,unknownPoint,unknownPoint,unknownPoint];
          }
          CGFloat effectiveAlpha=[(NSNumber *)entry[@"ancestorAlpha"] doubleValue]*v.alpha;
          BOOL ancestorHidden=[(NSNumber *)entry[@"ancestorHidden"] boolValue];
          NSMutableDictionary *props=[NSMutableDictionary dictionaryWithDictionary:@{ @"hidden":@(v.hidden), @"alpha":num(v.alpha), @"opaque":@(v.opaque), @"clipsToBounds":@(v.clipsToBounds), @"userInteractionEnabled":@(v.userInteractionEnabled), @"multipleTouchEnabled":@(v.multipleTouchEnabled), @"firstResponder":@(v.isFirstResponder), @"contentMode":@(v.contentMode), @"tag":@(v.tag), @"backgroundColor":color(v.backgroundColor,v.traitCollection), @"tintColor":color(v.tintColor,v.traitCollection), @"isAccessibilityElement":@(v.isAccessibilityElement), @"accessibilityTraits":@(v.accessibilityTraits), @"accessibilityElementsHidden":@(v.accessibilityElementsHidden), @"accessibilityViewIsModal":@(v.accessibilityViewIsModal), @"effectiveUserInterfaceLayoutDirection":@(v.effectiveUserInterfaceLayoutDirection), @"userInterfaceStyle":@(v.traitCollection.userInterfaceStyle), @"displayScale":num(v.traitCollection.displayScale), @"preferredContentSizeCategory":v.traitCollection.preferredContentSizeCategory ?: @"" }];
          if ([v isKindOfClass:[UILabel class]]) { UILabel *l=(UILabel *)v; props[@"label"]=@{ @"fontName":l.font.fontName ?: @"", @"fontSize":num(l.font.pointSize), @"numberOfLines":@(l.numberOfLines), @"lineBreakMode":@(l.lineBreakMode), @"textAlignment":@(l.textAlignment), @"adjustsFontSizeToFitWidth":@(l.adjustsFontSizeToFitWidth), @"minimumScaleFactor":num(l.minimumScaleFactor), @"textColor":color(l.textColor,v.traitCollection), @"textOmitted":@YES }; }
          if ([v isKindOfClass:[UIControl class]]) { UIControl *c=(UIControl *)v; props[@"control"]=@{ @"enabled":@(c.enabled), @"selected":@(c.selected), @"highlighted":@(c.highlighted), @"state":@(c.state) }; }
          if ([v isKindOfClass:[UITextField class]]) { UITextField *f=(UITextField *)v; props[@"textField"]=@{ @"secureTextEntry":@(f.secureTextEntry), @"editing":@(f.editing), @"textOmitted":@YES, @"fontSize":f.font ? num(f.font.pointSize) : (id)[NSNull null], @"textAlignment":@(f.textAlignment), @"textColor":color(f.textColor,v.traitCollection) }; }
          if ([v isKindOfClass:[UITextView class]]) { UITextView *tv=(UITextView *)v; props[@"textView"]=@{ @"secureTextEntry":@(tv.secureTextEntry), @"editable":@(tv.editable), @"selectable":@(tv.selectable), @"textOmitted":@YES, @"textContainerInset":insets(tv.textContainerInset), @"fontSize":tv.font ? num(tv.font.pointSize) : (id)[NSNull null] }; }
          if ([v isKindOfClass:[UIScrollView class]]) { UIScrollView *s=(UIScrollView *)v; props[@"scroll"]=@{ @"contentOffset":point(s.contentOffset), @"contentSize":size(s.contentSize), @"contentInset":insets(s.contentInset), @"adjustedContentInset":insets(s.adjustedContentInset), @"zoomScale":num(s.zoomScale), @"scrollEnabled":@(s.scrollEnabled), @"dragging":@(s.dragging), @"decelerating":@(s.decelerating), @"tracking":@(s.tracking), @"pagingEnabled":@(s.pagingEnabled) }; }
          NSArray *own=v.constraints, *horizontal=[v constraintsAffectingLayoutForAxis:UILayoutConstraintAxisHorizontal], *vertical=[v constraintsAffectingLayoutForAxis:UILayoutConstraintAxisVertical];
          BOOL ct=own.count>128||horizontal.count>128||vertical.count>128; constraintLimit=constraintLimit||ct;
          CALayer *l=v.layer; CATransform3D lt=l.transform;
          NSMutableDictionary *node=[NSMutableDictionary dictionaryWithDictionary:@{ @"id":ident(v), @"kind":@"view", @"class":NSStringFromClass([v class]), @"windowId":ident(w), @"depth":@(depth), @"geometry":@{ @"frame":rect(v.frame), @"bounds":rect(b), @"center":point(v.center), @"screenFrame":rect(sf), @"screenQuad":quad, @"coordinateSpace":@"screen-points", @"frameCoordinateSpace":@"superview", @"boundsCoordinateSpace":@"local", @"frameReliable":@(CGAffineTransformIsIdentity(t)), @"transform":@{ @"a":num(t.a), @"b":num(t.b), @"c":num(t.c), @"d":num(t.d), @"tx":num(t.tx), @"ty":num(t.ty) } }, @"properties":props, @"layout":@{ @"ambiguous":@(v.hasAmbiguousLayout), @"intrinsicSize":size(v.intrinsicContentSize), @"huggingHorizontal":num([v contentHuggingPriorityForAxis:UILayoutConstraintAxisHorizontal]), @"huggingVertical":num([v contentHuggingPriorityForAxis:UILayoutConstraintAxisVertical]), @"compressionHorizontal":num([v contentCompressionResistancePriorityForAxis:UILayoutConstraintAxisHorizontal]), @"compressionVertical":num([v contentCompressionResistancePriorityForAxis:UILayoutConstraintAxisVertical]), @"translatesAutoresizingMaskIntoConstraints":@(v.translatesAutoresizingMaskIntoConstraints), @"safeAreaInsets":insets(v.safeAreaInsets), @"layoutMargins":insets(v.layoutMargins), @"constraintsAffectingHorizontal":constraints(horizontal,128), @"constraintsAffectingVertical":constraints(vertical,128), @"constraintCounts":@{ @"own":@(own.count), @"horizontal":@(horizontal.count), @"vertical":@(vertical.count) }, @"constraintsTruncated":@(ct) }, @"constraints":constraints(own,128), @"layer":@{ @"class":NSStringFromClass([l class]), @"bounds":rect(l.bounds), @"position":point(l.position), @"anchorPoint":point(l.anchorPoint), @"zPosition":num(l.zPosition), @"opacity":num(l.opacity), @"hidden":@(l.hidden), @"masksToBounds":@(l.masksToBounds), @"cornerRadius":num(l.cornerRadius), @"borderWidth":num(l.borderWidth), @"borderColor":color(l.borderColor ? [UIColor colorWithCGColor:l.borderColor] : nil,v.traitCollection), @"backgroundColor":color(l.backgroundColor ? [UIColor colorWithCGColor:l.backgroundColor] : nil,v.traitCollection), @"shadowOpacity":num(l.shadowOpacity), @"shadowRadius":num(l.shadowRadius), @"shadowOffset":size(l.shadowOffset), @"shadowColor":color(l.shadowColor ? [UIColor colorWithCGColor:l.shadowColor] : nil,v.traitCollection), @"hasShadowPath":@(l.shadowPath!=NULL), @"hasMask":@(l.mask!=nil), @"shouldRasterize":@(l.shouldRasterize), @"rasterizationScale":num(l.rasterizationScale), @"contentsScale":num(l.contentsScale), @"sublayerCount":@(l.sublayers.count), @"animationKeys":l.animationKeys ?: @[], @"transform3D":@[num(lt.m11),num(lt.m12),num(lt.m13),num(lt.m14),num(lt.m21),num(lt.m22),num(lt.m23),num(lt.m24),num(lt.m31),num(lt.m32),num(lt.m33),num(lt.m34),num(lt.m41),num(lt.m42),num(lt.m43),num(lt.m44)] }, @"visibility":@{ @"hiddenSelf":@(v.hidden), @"hiddenByAncestor":@(ancestorHidden), @"effectiveAlpha":num(effectiveAlpha), @"intersectsScreen":@(CGRectIntersectsRect(sf,w.screen.bounds)), @"positiveBounds":@(b.size.width>0&&b.size.height>0), @"occlusion":@"unknown", @"ancestorClippingEvaluated":@NO, @"hitTestEvaluated":@NO }, @"childrenCount":@(v.subviews.count) }];
          if (!usableScreenRect) {
            NSMutableDictionary *visibility=[NSMutableDictionary dictionaryWithDictionary:node[@"visibility"]];
            visibility[@"intersectsScreen"]=[NSNull null];
            node[@"visibility"]=visibility;
          }
          if ([(NSString *)entry[@"parent"] length]) node[@"parentId"]=entry[@"parent"];
          if (v.accessibilityIdentifier.length) node[@"accessibilityIdentifier"]=v.accessibilityIdentifier;
          [nodes addObject:node];
          if (depth>=maxDepth) { if(v.subviews.count) { depthLimit=YES; node[@"childrenTruncated"]=@YES; } }
          else for (UIView *child in v.subviews) {
            if (queue.count >= (NSUInteger)maxNodes + windows.count) { nodeLimit=YES; node[@"childrenTruncated"]=@YES; break; }
            [queue addObject:@{ @"view":child, @"window":w, @"depth":@(depth+1), @"parent":ident(v), @"ancestorHidden":@(ancestorHidden||v.hidden), @"ancestorAlpha":@(effectiveAlpha) }];
          }
        }
        NSMutableDictionary *counts=[NSMutableDictionary dictionary];
        for (NSDictionary *n in nodes) { NSString *a=n[@"accessibilityIdentifier"]; if(a.length) counts[a]=@([(NSNumber *)counts[a] integerValue]+1); }
        for (NSMutableDictionary *n in nodes) { NSString *a=n[@"accessibilityIdentifier"]; if(a.length) n[@"accessibilityIdentifierUniqueInCapture"]=@([(NSNumber *)counts[a] integerValue]==1); }
        NSMutableDictionary *capture=[NSMutableDictionary dictionaryWithDictionary:@{ @"id":[NSString stringWithUTF8String:captureID], @"timestamp":[NSString stringWithUTF8String:timestamp], @"provider":@"lldb-public-uikit", @"coherence":@"main-thread-expression-while-process-stopped; model-layer-state; screenshot-not-atomic", @"truncated":@(nodeLimit||depthLimit||constraintLimit), @"nodeLimitReached":@(nodeLimit), @"depthLimitReached":@(depthLimit), @"constraintLimitReached":@(constraintLimit), @"byteLimitReached":@NO, @"limits":@{ @"maxNodes":@(maxNodes), @"maxDepth":@(maxDepth), @"maxBytes":@(maxBytes), @"constraintsPerList":@128 }, @"windows":windowInfo, @"limitations":@[ @"No logical SwiftUI tree or source provenance", @"No independent CALayer or UIViewController graph", @"No private compositor facts or Xcode issue engine", @"Text, accessibility labels and values intentionally omitted; secure fields redacted", @"Getter evaluation may run custom app code; no layout forcing or hit testing performed", @"Occlusion and ancestor clipping are not established", @"Constraint references may point outside the captured view set", @"Pointer identifiers are ephemeral; uniqueness is capture-local", @"Raw enum values follow the installed SDK; nonfinite numeric values are null" ] }];
        NSMutableDictionary *root=[NSMutableDictionary dictionaryWithDictionary:@{ @"schemaVersion":@"ios-ui-evidence/v1", @"capture":capture, @"target":@{ @"bundleId":[NSBundle mainBundle].bundleIdentifier ?: @"", @"pid":@([NSProcessInfo processInfo].processIdentifier), @"processName":[NSProcessInfo processInfo].processName ?: @"", @"osVersion":[NSProcessInfo processInfo].operatingSystemVersionString ?: @"" }, @"nodes":nodes }];
        NSError *error=nil; NSData *data=[NSJSONSerialization dataWithJSONObject:root options:0 error:&error];
        NSUInteger removed=0;
        while (data.length>=maxBytes && nodes.count) {
          NSUInteger removeCount=MAX((NSUInteger)1,nodes.count/2); [nodes removeObjectsInRange:NSMakeRange(nodes.count-removeCount,removeCount)]; removed+=removeCount;
          capture[@"truncated"]=@YES; capture[@"byteLimitReached"]=@YES; capture[@"nodesRemovedForByteLimit"]=@(removed);
          data=[NSJSONSerialization dataWithJSONObject:root options:0 error:&error];
        }
        if(data && data.length<maxBytes) { result=(char *)malloc(data.length+1); if(result) { memcpy(result,data.bytes,data.length); result[data.length]='\0'; } }
      }
    }
    (unsigned long long)result;
});
}
extern "C" __attribute__((visibility("default"))) int PuppetUIIsMainThread(void) { return [NSThread isMainThread] ? 1 : 0; }
extern "C" __attribute__((visibility("default"))) int PuppetUIFree(unsigned long long address) { free((void *)address); return 1; }
