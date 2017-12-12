//
//  DanmuManage.swift
//  DanmuSwift
//
//  Created by 孙伟伟 on 2017/11/1.
//  Copyright © 2017年 孙伟伟. All rights reserved.
//

import Foundation
import UIKit
import libkern

class DanmuManage: UIView {
    
    public var isPlaying = false;
    public var spinLock = OSSpinLock();
    public var sourceQueue  =  OperationQueue();
    public var renderQueue  =  DispatchQueue(label: "renderQueue");
    var displayLink:CADisplayLink? = nil;
    
    //用户刚刚发送过来的弹幕数据，暂存
    lazy var fetchDanmakusArray : [DanmuView] = {
        let array = NSMutableArray()
        return array as! [DanmuView]
    }()
    
    //已经使用的弹道，从中可以取出前一个弹道的弹幕，进行碰撞判断
    lazy var showingDanmakusTrajectoryDict : NSMutableDictionary = {
        let dict = NSMutableDictionary()
        return dict
    }()
    
    //已经开始绘制显示在界面UI上的弹幕，暂存
    lazy var renderingDanmakusArray : NSMutableArray = {
        let array = NSMutableArray()
        return array
    }()
    
    lazy var cellReusePool : NSMutableDictionary = {
        let dict = NSMutableDictionary()
        return dict
    }()
    
    lazy var cellClassInfo : NSMutableDictionary = {
        let dict = NSMutableDictionary()
        return dict
    }()
    
    
    override init(frame: CGRect) {
        super.init(frame: frame);
        
        self.sourceQueue.name = "danmakuSourceQueue";
        self.sourceQueue.maxConcurrentOperationCount = 1;
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func sendDanmu (_ ljDanmu : DanmuView?){
        if ljDanmu == nil {
            return ;
        }
        OSSpinLockLock(&self.spinLock);
        self.fetchDanmakusArray.append(ljDanmu!);
        OSSpinLockUnlock(&self.spinLock);
        
        self.loadDanmakusFromFetchDanmakusArray();
    }
    
    func play() {
        if (self.isPlaying) { return };
        self.isPlaying = true;
        
        self.resumeShowingDanmakus();
        
        if (self.displayLink == nil) {
            self.displayLink = CADisplayLink(target: self, selector: #selector(DanmuManage.handleData))
            self.displayLink?.isPaused = false; //开始
            //每5帧处理一次 大概 一秒60/5次
            self.displayLink?.frameInterval = Int(60.0 * ljFrameInterval);
            self.displayLink?.add(to: RunLoop.main, forMode: .commonModes)
        }
    }
    
    func pause() {
        if (!self.isPlaying) { return };
        self.isPlaying = false;
        
        self.displayLink?.isPaused = true;
        self.displayLink?.invalidate();
        self.displayLink = nil;
        self.pauseShowingDanmakus();
    }
    
    func stop() {
        self.isPlaying = false;
        self.displayLink?.isPaused = true;
        self.displayLink?.invalidate();
        self.displayLink = nil;
        self.clearScreen();
    }
    
    func clearScreen(){
        print("clearScreen");
        self.recycleDanmaku(danmakuArrays: self.renderingDanmakusArray as! Array<DanmuView>);
        self.renderQueue.async(){
            self.renderingDanmakusArray.removeAllObjects();
        };
    }
}

extension DanmuManage {
    // MARK - CADisplayLink所有视图遍历---时间递减
    @objc  func handleData() {
        self.loadDanmakusFromFetchDanmakusArray();
        self.renderDanmakusForTime();
    }
    
    func loadDanmakusFromFetchDanmakusArray() {
        
        let operation : BlockOperation = BlockOperation.init(block: {
            OSSpinLockLock(&self.spinLock);
            
            //            var number = "remainingTime <= 0";
            //            var numberPre = NSPredicate(format: "SELF MATCHES %@", number);
            //            var danmakuArrays = numberPre.evaluate(with: self.fetchDanmakusArray);
            
            //            let danmakuArrays : [DanmuView] = self.fetchDanmakusArray.filter(NSPredicate.init(format: "SELF MATCHES %@", number));
            
            var danmakuArrays : [DanmuView] = NSMutableArray.init() as! [DanmuView];
            for info : DanmuView in self.fetchDanmakusArray {
                if info.remainingTime == 0 {
                    info.remainingTime = Float(Duration);
                    danmakuArrays.append(info);
                }
            }
            OSSpinLockUnlock(&self.spinLock);
            
            for danmaku : DanmuView in danmakuArrays {
                danmaku.remainingTime = Float(Duration);
                //NSLog(@"loadDanmakusFromFetchDanmakusArray---remainingTime:%f", danmaku.remainingTime);
                // MARK - 给每个danmaku赋予值5s
            }
        });
        self.sourceQueue.cancelAllOperations();
        self.sourceQueue.addOperation(operation);
    }
    
    func renderDanmakusForTime() {
        self.renderQueue.async(){
            self.renderShowingDanmakusForInterval();
            self.renderNewDanmakusForData();
        };
    }
    // Mark -- 所有视图遍历---时间递减
    func renderShowingDanmakusForInterval() {
        let disappearDanmakuArray = NSMutableArray();
        self.renderingDanmakusArray.enumerateObjects({ (value, idx, stop) in
            //            print(value, idx)
            let danmaku : DanmuView = value as! DanmuView;
            
            if (danmaku.remainingTime != nil) {
                danmaku.remainingTime = danmaku.remainingTime! - Float(ljFrameInterval);
                //            print("renderDisplayingDanmakus:-\(String(describing: danmaku.remainingTime))");
                if (danmaku.remainingTime! < Float(0.0) || danmaku.remainingTime! == Float(0.0) ) {
                    disappearDanmakuArray.add(danmaku);
                    OSSpinLockLock(&self.spinLock);
                    self.renderingDanmakusArray.removeObject(at: idx);
                    OSSpinLockUnlock(&self.spinLock);
                }
            }
        });
        //弹幕回收再利用
        self.recycleDanmaku(danmakuArrays: disappearDanmakuArray as! Array<DanmuView>);
    }
    
    func renderNewDanmakusForData() {
        OSSpinLockLock(&self.spinLock);
        let ljArray : [DanmuView] = NSMutableArray.init(array: self.fetchDanmakusArray) as! [DanmuView];
        self.fetchDanmakusArray.removeAll();
        OSSpinLockUnlock(&self.spinLock);
        
        for danmaku : DanmuView in ljArray{
            self.renderNewDanmaku(danmaku);
        }
    }
    
    // MARK -   最后一步渲染-----显示
    func renderNewDanmaku(_ danmaku : DanmuView) {
        if !self.layoutNewDanmaku(danmaku) {
            return ;
        }
        
        OSSpinLockLock(&self.spinLock);
        self.renderingDanmakusArray.add(danmaku);
        OSSpinLockUnlock(&self.spinLock);
        
        DispatchQueue.main.async {
            let cell : DanmuView? = danmaku;
            if (cell != nil) {
                cell?.frame = CGRect(x: danmaku.px!, y: danmaku.py!, width: (danmaku.size?.width)!, height: (danmaku.size?.height)!);
                self.insertSubview(cell!, at: 20);
                
                if danmaku.remainingTime == nil{
                    danmaku.remainingTime = 0;
                }
                UIView.animate(withDuration:Double(danmaku.remainingTime!), delay: 0, options: .curveLinear, animations: {
                    let  yx : CGFloat = (cell!.size?.width)!;
                    cell?.frame = CGRect(x: -yx, y: (cell?.py!)!, width: (cell?.size!.width)!, height: (cell?.size!.height)!);
                }, completion: { (finished : Bool) in
                    
                })
            }
        };
    }
    
    func layoutNewDanmaku(_ danmaku : DanmuView) -> Bool {
        
        let width = DanmuDefine.shared.getTextCGSize((danmaku.ljBulletLabel?.text!)!, UIFont.systemFont(ofSize: 14)).width + 1.0;
        danmaku.size = CGSize(width: width, height: CGFloat(CellHeight))
        
        OSSpinLockLock(&self.spinLock);
        let py : Float = self.layoutPyWithLRDanmaku(danmaku);
        OSSpinLockUnlock(&self.spinLock);
        
        if (py < 0) {
            return false;
        }
        danmaku.py = CGFloat(py);
        danmaku.px = AppWidth;
        
        return true;
    }
    
    //#pragma mark -- 通道判断&高度返回
    //1.当前通道是有视图的话，进行碰撞判断
    //2.当前通道没view的直接返回显示的高度
    
    func layoutPyWithLRDanmaku(_ danmaku : DanmuView) -> Float {
        let maxPyIndex : Int = Int(self.bounds.height) / Int(CellHeight);
        let trajectory : NSMutableDictionary = self.showingDanmakusTrajectoryDict;
        for index in 0...maxPyIndex {
            let key : NSNumber = NSNumber.init(value: index);
            var tempDanmaku : DanmuView?;
            if (trajectory.object(forKey: index) != nil){
                tempDanmaku = trajectory.object(forKey: index) as? DanmuView;
            }
            if (tempDanmaku == nil) {
                danmaku.yIdx = index;
                trajectory[key] = danmaku;
                
                //返回的高度
                //                print("当前通道没view的直接返回显示的高度:%d----\(index)");
                return Float((CellHeight + CellSpace) * index);
            }
            //当前通道是有视图的话，进行碰撞判断
            if (!self.judgeHitWithPreDanmaku(tempDanmaku!, danmaku)) {
                danmaku.yIdx = index;
                trajectory[key] = danmaku;
                //NSLog(@"当前通道有视图 * index %d----",cellHeight * index);
                return Float((CellHeight + CellSpace) * index);
            }
        }
        return -1;
    }
    
    //弹幕碰撞检测 YES:会碰撞  NO：不会碰撞
    func judgeHitWithPreDanmaku(_ preDanmaku : DanmuView , _ danmaku : DanmuView) -> Bool {
        
        if preDanmaku.remainingTime != nil {
            //1.前一个弹幕是否还在移动？【显示时间每次递减0.2s】
            if (preDanmaku.remainingTime! <= Float(0.0)) {
                return false; //说明前一个弹幕已经移出了屏幕，不会碰撞
            }
            //屏幕的宽度
            let width = self.bounds.width;
            
            //5s显示时间下的弹幕移动速度
            let preDanmakuSpeed = (width + (preDanmaku.size?.width)!) / CGFloat(Duration);
            
            //2.已经移入屏幕的距离与弹幕要移动的总距离比较
            if (preDanmakuSpeed * (CGFloat(Duration) -  CGFloat(preDanmaku.remainingTime!)) < (preDanmaku.size?.width)!) {
                return true; //说明弹幕未完全进入屏幕，只有一部分进入了屏幕，会发生碰撞
            }
            
            //3.当前弹幕能否追得上前一个弹幕？
            let currentDanmakuSpeed = (width + (danmaku.size?.width)!) / CGFloat(Duration);
            if (currentDanmakuSpeed * CGFloat(preDanmaku.remainingTime!) > width) {
                return true; //可以追得上，会发生碰撞
            }
            return false;
        }
        return false;
    }
    
    func pauseShowingDanmakus() {
        if ((self.visibleDanmakus()?.count) != nil)
        {
            let danmakus = self.visibleDanmakus() as! [DanmuView];
            DispatchQueue.main.async {
                for danmaku : DanmuView in danmakus{
                    let layer = danmaku.layer;
                    danmaku.frame = (layer.presentation()?.frame)!;
                    danmaku.layer.removeAllAnimations();
                }
            }
        }
    }
    
    func visibleDanmakus() -> NSArray? {
        var renderingDanmakus : NSArray?;
        //        self.renderQueue.async() {
        renderingDanmakus = NSArray.init(array: self.renderingDanmakusArray);
        print("-------\(String(describing: renderingDanmakus))");
        
        //            return (self.renderingDanmakus);
        //        };
        return (renderingDanmakus);
    }
    
    func resumeShowingDanmakus(){
        
        if ((self.visibleDanmakus()?.count) != nil)
        {
            let renderingDanmakus = self.visibleDanmakus() as! [DanmuView];
            for danmaku : DanmuView in renderingDanmakus{
                if danmaku.remainingTime == nil{
                    danmaku.remainingTime = 0;
                }
                
                UIView.animate(withDuration: Double(danmaku.remainingTime!), delay: 0, options: .curveLinear, animations: {
                    let  yx : CGFloat = (danmaku.size?.width)!;
                    danmaku.frame = CGRect(x: -yx, y: danmaku.py!, width: danmaku.size!.width, height: danmaku.size!.height);
                }, completion: { (finished) in
                    
                });
            }
        }
    }
    // 弹幕重用---避免很多弹幕时，内存急剧增大
    func recycleDanmaku(danmakuArrays : Array<DanmuView>){
        if danmakuArrays.count == 0 {
            return;
        }
        DispatchQueue.main.async {
            for danmaku : DanmuView in danmakuArrays{
                danmaku.layer.removeAllAnimations();
                danmaku.removeFromSuperview();
                danmaku.yIdx = -1;
                danmaku.remainingTime = 0;
                self.recycleCellToReusePool(danmakuCell: danmaku);
            }
        };
    }
    
    func recycleCellToReusePool(danmakuCell : DanmuView) {
        let identifier = danmakuCell.reuseIdentifier;
        if identifier == nil {
            return;
        }
        OSSpinLockLock(&self.spinLock);
        var cells : NSMutableArray? = self.cellReusePool.object(forKey: identifier!) as? NSMutableArray;
        if cells == nil {
            cells = NSMutableArray();
            self.cellReusePool[identifier!] = cells;
        }
        cells?.add(danmakuCell);
        OSSpinLockUnlock(&self.spinLock);
    }
    
    func registerClass(cellClass : AnyClass, identifier : String?) {
        if identifier == nil {
            return;
        }
        self.cellClassInfo[identifier!] = cellClass;
    }
    
    func dequeueReusableDanmaWithIdentifier(_ identifier : String) -> DanmuView? {
        
        var cells : NSMutableArray?;
        if (self.cellReusePool.object(forKey:identifier) != nil){
            cells = (self.cellReusePool.object(forKey:identifier) as! NSMutableArray) ;
        }
        
        if cells?.count == 0 && (self.cellClassInfo.object(forKey:identifier) != nil)
        {
            let cellClass : DanmuView = self.cellClassInfo.object(forKey:identifier) as! DanmuView;
            //            let danmucell = cellClass.init(frame:CGRect(x: 0, y: 0, width: 0, height: 25));
            return cellClass.initWithReuseIdentifier(identifier) as? DanmuView;
        }
        OSSpinLockLock(&self.spinLock);
        
        var cell : DanmuView?;
        if cells?.lastObject != nil{
            //            let cell : DanmuView = cells?.lastObject as! DanmuView;
            cell = cells?.lastObject as? DanmuView;
            cells?.removeLastObject();
            
        }
        OSSpinLockUnlock(&self.spinLock);
        return cell;
        //        let cell : DanmuView = cells!.lastObject as! DanmuView;
        //        cells?.removeLastObject();
        //        OSSpinLockUnlock(&self.spinLock);
        //        return nil;
    }
}



