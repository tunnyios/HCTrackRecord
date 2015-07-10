//
//  ViewController.m
//  BaiduMap轨迹记录
//
//  Created by tunny on 15/7/9.
//  Copyright (c) 2015年 tunny. All rights reserved.
//

#import "ViewController.h"
#import "globalVariable.h"
#import <BaiduMapAPI/BMapKit.h>

typedef enum : NSUInteger {
    HCTrailOther = 0,
    HCTrailStart,
    HCTrailEnd,
} HCTrail;

@interface ViewController () <BMKMapViewDelegate, BMKLocationServiceDelegate>
/** 百度地图View */
@property (weak, nonatomic) IBOutlet BMKMapView *bmkMapView;
/** 百度定位地图服务 */
@property (nonatomic, strong) BMKLocationService *bmkLocationService;
/** 记录上一次的位置 */
@property (nonatomic, strong) CLLocation *preLocation;
/** 位置数组 */
@property (nonatomic, strong) NSMutableArray *locationArrayM;
/** 轨迹 */
@property (nonatomic, strong) BMKPolyline *polyLine;
/** 轨迹记录状态 */
@property (nonatomic, assign) HCTrail trail;
/** 起点大头针 */
@property (nonatomic, strong) BMKPointAnnotation *startPoint;
/** 终点大头针 */
@property (nonatomic, strong) BMKPointAnnotation *endPoint;

@end

@implementation ViewController

- (NSMutableArray *)locationArrayM
{
    if (_locationArrayM == nil) {
        _locationArrayM = [NSMutableArray array];
    }
    
    return _locationArrayM;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _bmkLocationService = [[BMKLocationService alloc] init];
    
    //设置更新位置频率(单位：米;必须要在开始定位之前设置)
    [BMKLocationService setLocationDistanceFilter:1];
    [BMKLocationService setLocationDesiredAccuracy:kCLLocationAccuracyBestForNavigation];
    
    [_bmkLocationService startUserLocationService];

    
    self.bmkMapView.showsUserLocation = YES;
    self.bmkMapView.userTrackingMode = BMKUserTrackingModeFollow;
}

- (void)viewWillAppear:(BOOL)animated
{
    [_bmkMapView viewWillAppear];
    _bmkMapView.delegate = self; // 此处记得不用的时候需要置nil，否则影响内存的释放
    _bmkLocationService.delegate = self;
}
- (void)viewWillDisappear:(BOOL)animated
{
    [_bmkMapView viewWillDisappear];
    _bmkMapView.delegate = nil; // 不用时，置nil
    _bmkLocationService.delegate = nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/**
 *  开始记录轨迹
 */
- (IBAction)start
{
    //清理地图
    [self clean];
    
    self.trail = HCTrailStart;
}

/**
 *  继续记录轨迹
 */
- (IBAction)continueRecord
{
    self.trail = HCTrailStart;
}

/**
 *  停止记录轨迹
 */
- (IBAction)stop
{
    self.trail = HCTrailEnd;
}

#pragma mark - BMKLocationServiceDelegate

/**
 *  更新用户位置(调用频繁)
 */
- (void)didUpdateBMKUserLocation:(BMKUserLocation *)userLocation
{
    [self.bmkMapView updateLocationData:userLocation];
//    DLog(@"<%f, %f>", userLocation.location.coordinate.latitude, userLocation.location.coordinate.longitude);
    
    if (HCTrailStart == self.trail) {
        //开始记录轨迹
        [self startTrailRouteWithUserLocation:userLocation];
    } else if (HCTrailEnd == self.trail) {
        //设置终点大头针
        self.endPoint = [self creatPointWithLocaiton:userLocation.location title:@"终点"];
        self.trail = HCTrailOther;
    }
}


/**
 *  更新用户方向(调用频繁)
 */
- (void)didUpdateUserHeading:(BMKUserLocation *)userLocation
{
    [self.bmkMapView updateLocationData:userLocation];
    
//    DLog(@"<%f, %f>", userLocation.location.coordinate.latitude, userLocation.location.coordinate.longitude);
}

#pragma mark - BMKMapViewDelegate


- (BMKOverlayView *)mapView:(BMKMapView *)mapView viewForOverlay:(id<BMKOverlay>)overlay
{
    if ([overlay isKindOfClass:[BMKPolyline class]]) {
        BMKPolylineView* polylineView = [[BMKPolylineView alloc] initWithOverlay:overlay];
        polylineView.fillColor = [[UIColor cyanColor] colorWithAlphaComponent:1];
        polylineView.strokeColor = [[UIColor blueColor] colorWithAlphaComponent:0.7];
        polylineView.lineWidth = 3.0;
        return polylineView;
    }
    return nil;
}

/**
 *  只有在添加大头针的时候会调用，直接在viewDidload中不会调用
 */
- (BMKAnnotationView *)mapView:(BMKMapView *)mapView viewForAnnotation:(id <BMKAnnotation>)annotation
{
    NSString *AnnotationViewID = @"renameMark";
    BMKPinAnnotationView *annotationView = (BMKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:AnnotationViewID];
    if (annotationView == nil) {
        annotationView = [[BMKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:AnnotationViewID];
        // 设置颜色
        annotationView.pinColor = BMKPinAnnotationColorPurple;
        // 从天上掉下效果
        annotationView.animatesDrop = YES;
        // 设置可拖拽
        annotationView.draggable = YES;
    }
    return annotationView;
}

#pragma mark - 中间方法
/**
 *  开始记录轨迹
 *
 *  @param userLocation 实时更新的位置信息
 */
- (void)startTrailRouteWithUserLocation:(BMKUserLocation *)userLocation
{
    CLLocationCoordinate2D userLocationCoor = userLocation.location.coordinate;
    CLLocation *location = [[CLLocation alloc] initWithLatitude:userLocationCoor.latitude longitude:userLocationCoor.longitude];
    
    //1. 每5米记录一个点
    if (self.locationArrayM.count > 0) {
        CLLocationDistance distance = [location distanceFromLocation:self.preLocation];
        DLog(@"distance:%f", distance);
        if (distance < 5) {
            return;
        }
    }
    
    //2. 记录
    [self.locationArrayM addObject:location];
    DLog(@"count %lu", (unsigned long)self.locationArrayM.count);
    self.preLocation = location;
    
    //3. 绘图
    [self onGetWalkPolyline];
}

/**
 *  绘制步行轨迹路线
 */
- (void)onGetWalkPolyline
{
    //轨迹点
    NSUInteger count = self.locationArrayM.count;
    BMKMapPoint *tempPoints = new BMKMapPoint[count];
    [self.locationArrayM enumerateObjectsUsingBlock:^(CLLocation *location, NSUInteger idx, BOOL *stop) {
        BMKMapPoint locationPoint = BMKMapPointForCoordinate(location.coordinate);
        tempPoints[idx] = locationPoint;
        
        //设置起点
        if (0 == idx && HCTrailStart == self.trail) {
            self.startPoint = [self creatPointWithLocaiton:location title:@"起点"];
        }
    }];
    
    //移除原有的绘图
    if (self.polyLine) {
        [_bmkMapView removeOverlay:self.polyLine];
    }
    
    // 通过points构建BMKPolyline
    self.polyLine = [BMKPolyline polylineWithPoints:tempPoints count:count];
    
    //添加路线,绘图
    if (self.polyLine) {
        [_bmkMapView addOverlay:self.polyLine];
    }
    delete []tempPoints;
    [self mapViewFitPolyLine:self.polyLine];
}

/**
 *  添加一个大头针
 *
 *  @param location
 */
- (BMKPointAnnotation *)creatPointWithLocaiton:(CLLocation *)location title:(NSString *)title;
{
    BMKPointAnnotation *point = [[BMKPointAnnotation alloc] init];
    point.coordinate = location.coordinate;
    point.title = title;
    
    [_bmkMapView addAnnotation:point];
    
    return point;
}

/**
 *  清空数组以及地图上的轨迹
 */
- (void)clean
{
    //清空数组
    [self.locationArrayM removeAllObjects];
    //清屏
    if (_startPoint) {
        [_bmkMapView removeAnnotation:self.startPoint];
    }
    if (_endPoint) {
        [_bmkMapView removeAnnotation:self.endPoint];
    }
    if (_polyLine) {
        [_bmkMapView removeOverlay:self.polyLine];
    }
}

/**
 *  根据polyline设置地图范围
 *
 *  @param polyLine
 */
- (void)mapViewFitPolyLine:(BMKPolyline *) polyLine {
    CGFloat ltX, ltY, rbX, rbY;
    if (polyLine.pointCount < 1) {
        return;
    }
    BMKMapPoint pt = polyLine.points[0];
    ltX = pt.x, ltY = pt.y;
    rbX = pt.x, rbY = pt.y;
    for (int i = 1; i < polyLine.pointCount; i++) {
        BMKMapPoint pt = polyLine.points[i];
        if (pt.x < ltX) {
            ltX = pt.x;
        }
        if (pt.x > rbX) {
            rbX = pt.x;
        }
        if (pt.y > ltY) {
            ltY = pt.y;
        }
        if (pt.y < rbY) {
            rbY = pt.y;
        }
    }
    BMKMapRect rect;
    rect.origin = BMKMapPointMake(ltX , ltY);
    rect.size = BMKMapSizeMake(rbX - ltX, rbY - ltY);
    [_bmkMapView setVisibleMapRect:rect];
    _bmkMapView.zoomLevel = _bmkMapView.zoomLevel - 0.3;
}

@end
