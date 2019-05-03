//
//  UIImageCropper.swift
//  UIImageCropper
//
//  Created by Jari Kalinainen jari@klubitii.com
//
//  Licensed under MIT License 2017
//

import UIKit

protocol CropViewDelegate : class {
    func didEndResizing(_ cropView: CropView)
    func onResizing(_ cropView: CropView)
}

class CropView : UIView {

    weak var delegate: CropViewDelegate?

    private var originalFrame: CGRect = .zero
    private var touchDownAbsPoint: CGPoint = .zero
    private var touchDownRelPoint: CGPoint = .zero
    private let touchDistance: CGFloat = 30
    private var canResize = false

    enum Corner {
        case none
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }

    private var corner: Corner = .none

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        isUserInteractionEnabled = true
    }

    private func isTopLeftCorner(point: CGPoint) -> Bool {
        return point.x <= touchDistance && point.y <= touchDistance
    }

    private func isTopRightCorner(point: CGPoint) -> Bool {
        return abs(self.bounds.width.distance(to: point.x)) <= touchDistance && point.y <= touchDistance
    }

    private func isBottomLeftCorner(point: CGPoint) -> Bool {
        return point.x <= touchDistance && abs(self.bounds.height.distance(to: point.y)) <= touchDistance
    }

    private func isBottomRightCorner(point: CGPoint) -> Bool {
        return abs(self.bounds.width.distance(to: point.x)) <= touchDistance && abs(self.bounds.height.distance(to: point.y)) <= touchDistance
    }

    private func isInCorner(point: CGPoint) -> Bool {
        return isTopLeftCorner(point: point)
        || isTopRightCorner(point: point)
        || isBottomLeftCorner(point: point)
        || isBottomRightCorner(point: point)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
            let containerView = superview else {
            return
        }
        touchDownAbsPoint = touch.location(in: containerView)
        touchDownRelPoint = touch.location(in: self)
        originalFrame = self.frame
        if isTopRightCorner(point: touchDownRelPoint) {
            corner = .topRight
            canResize = true
        } else if isTopLeftCorner(point: touchDownRelPoint) {
            corner = .topLeft
            canResize = true
        } else if isBottomLeftCorner(point: touchDownRelPoint) {
            corner = .bottomLeft
            canResize = true
        } else if isBottomRightCorner(point: touchDownRelPoint) {
            corner = .bottomRight
            canResize = true
        } else {
            corner = .none
            canResize = false
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return isInCorner(point: point) ? self : nil
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        delegate?.didEndResizing(self)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        delegate?.didEndResizing(self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
            let containerView = superview,
            canResize else {
            return
        }

        let point = touch.location(in: containerView)
        let diffX = point.x - touchDownAbsPoint.x
        let diffY = point.y - touchDownAbsPoint.y

        let distance = sqrt(pow(diffX, 2) + pow(diffY, 2))
        var f = originalFrame
        let ratio = f.size.height / f.size.width
        var sign: CGFloat = 1
        switch corner {
        case .topLeft:
            sign = (diffX <= 0 && diffY <= 0) ? -1 : 1
            f.origin.x += sign * distance
            f.origin.y += sign * distance * ratio
            f.size.width -= sign * distance
            f.size.height -= sign * distance * ratio
        case .bottomLeft:
            sign = (diffX <= 0 && diffY >= 0) ? 1 : -1
            f.origin.x -= sign * distance
            //f.origin.y -= sign * distance * ratio
            f.size.width += sign * distance
            f.size.height += sign * distance * ratio
        case .topRight:
            sign = (diffX >= 0 && diffY <= 0) ? 1 : -1
            f.origin.y -= sign * distance * ratio
            f.size.width += sign * distance
            f.size.height += sign * distance * ratio
        case .bottomRight:
            sign = (diffX >= 0 && diffY >= 0) ? 1 : -1
            f.size.width += sign * distance
            f.size.height += sign * distance * ratio
        default: break
        }

        if f.origin.x < 0 {
            f.origin.x = 0
        }
        if f.origin.y < 0 {
            f.origin.y = 0
        }
        if f.origin.x + f.size.width > containerView.bounds.width {
            f.size.width = containerView.bounds.width - f.origin.x
        }
        if f.origin.y + f.size.height > containerView.bounds.height {
            f.size.height = containerView.bounds.height - f.origin.y
        }

        self.frame = f
        //print("diffX = \(Int(diffX)), diffY = \(Int(diffY)), sign = \(sign), distance = \(Int(distance)), width = \(Int(frame.size.width)), height = \(Int(frame.size.height))")
        setNeedsLayout()
        layoutIfNeeded()

        delegate?.onResizing(self)
    }
}


@objc public protocol UIImageCropperProtocol: class {
    /// Called when user presses crop button (or when there is unknown situation (one or both images will be nil)).
    /// - parameter originalImage
    ///   Orginal image from camera/gallery
    /// - parameter croppedImage
    ///   Cropped image in cropRatio aspect ratio
    func didCropImage(originalImage: UIImage?, croppedImage: UIImage?)
    /// (optional) Called when user cancels the picker. If method is not available picker is dismissed.
    @objc optional func didCancel()
}

extension UIImageCropper : CropViewDelegate {
    func onResizing(_ cropView: CropView) {
        maskFadeView()
    }

    func didEndResizing(_ cropView: CropView) {
        let centerDiffX = cropView.center.x - imageView.center.x
        let centerDiffY = cropView.center.y - imageView.center.y
        let scale = topView.bounds.width / cropView.bounds.width

        var newCropViewFrame = cropView.frame
        newCropViewFrame.origin.x = 0
        newCropViewFrame.size.width = self.topView.bounds.width
        newCropViewFrame.size.height = self.topView.bounds.width * (1 / self.cropRatio)

        var newImageViewFrame = imageView.frame
        newImageViewFrame.size.width = imageView.bounds.width * scale
        newImageViewFrame.size.height = imageView.bounds.height * scale
        var imageCenter = imageView.center
        imageCenter.x = topView.center.x - centerDiffX * scale
        imageCenter.y = topView.center.y - centerDiffY * scale

        self.imageView.isUserInteractionEnabled = false
        self.cropView.isUserInteractionEnabled = false

        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseOut], animations: {
            self.cropView.frame = newCropViewFrame
            self.cropView.center = self.topView.center
            self.imageView.frame = newImageViewFrame
            self.imageView.center = imageCenter

        }, completion: { _ in
            self.imageView.isUserInteractionEnabled = true
            self.cropView.isUserInteractionEnabled = true
        })

        maskFadeView()
    }
}

public class UIImageCropper: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    /// Aspect ratio of the cropped image
    public var cropRatio: CGFloat = 1
    /// delegate that implements UIImageCropperProtocol
    public weak var delegate: UIImageCropperProtocol?
    /// UIImagePickerController picker
    public weak var picker: UIImagePickerController? {
        didSet {
            picker?.delegate = self
            picker?.allowsEditing = false
        }
    }

    /// Crop button text
    public var cropButtonText: String = "Crop"
    /// Retake/Cancel button text
    public var cancelButtonText: String = "Retake"

    /// original image from camera or gallery
    public var image: UIImage? {
        didSet {
            guard let image = self.image else {
                return
            }
            ratio = image.size.height / image.size.width
            imageView.image = image
            self.view.layoutIfNeeded()
        }
    }
    /// cropped image
    public var cropImage: UIImage? {
        return crop()
    }

    /// autoClosePicker: if true, picker is dismissed when when image is cropped. When false parent needs to close picker.
    public var autoClosePicker: Bool = true

    private let topView = UIView()
    private let fadeView = UIView()
    private let imageView: UIImageView = UIImageView()
    private lazy var cropView: UIView = {
        let v = CropView()
        v.delegate = self
        return v
    }()

    private var ratio: CGFloat = 1

    private var orgHeight: CGFloat = 0
    private var orgWidth: CGFloat = 0
    private var panXStart: CGFloat = 0
    private var panYStart: CGFloat = 0
    private var pinchStart: CGPoint = .zero
    
    private let cropButton = UIButton(type: .custom)
    private let cancelButton = UIButton(type: .custom)
    
    //MARK: - inits
    /// initializer
    /// - parameter cropRatio
    /// Aspect ratio of the cropped image
    convenience public init(cropRatio: CGFloat) {
        self.init()
        self.cropRatio = cropRatio
    }

    //MARK: - overrides
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.black

        //main views
        topView.backgroundColor = UIColor.clear
        let bottomView = UIView()
        bottomView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        self.view.addSubview(topView)
        self.view.addSubview(bottomView)

        topView.translatesAutoresizingMaskIntoConstraints = false
        bottomView.translatesAutoresizingMaskIntoConstraints = false
        let horizontalTopConst = NSLayoutConstraint.constraints(withVisualFormat: "H:|[view]|", options: NSLayoutConstraint.FormatOptions(), metrics: nil, views: ["view": topView])
        let horizontalBottomConst = NSLayoutConstraint.constraints(withVisualFormat: "H:|[view]|", options: NSLayoutConstraint.FormatOptions(), metrics: nil, views: ["view": bottomView])
        let verticalConst = NSLayoutConstraint.constraints(withVisualFormat: "V:|[top][bottom(70)]|", options: NSLayoutConstraint.FormatOptions(), metrics: nil, views: ["bottom": bottomView, "top": topView])
        self.view.addConstraints(horizontalTopConst + horizontalBottomConst + verticalConst)

        // image view
        imageView.image = self.image
        imageView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.width * ratio)
        imageView.contentMode = .scaleAspectFit

        topView.addSubview(imageView)
        topView.layer.borderWidth = 1.0
        topView.layer.borderColor = UIColor.red.cgColor

        imageView.layer.borderWidth = 1.0
        imageView.layer.borderColor = UIColor.blue.cgColor

        // imageView gestures
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(pinch))
        topView.addGestureRecognizer(pinchGesture)
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(pan))
        imageView.addGestureRecognizer(panGesture)
        imageView.isUserInteractionEnabled = true

        //fade overlay
        fadeView.translatesAutoresizingMaskIntoConstraints = false
        fadeView.isUserInteractionEnabled = false
        fadeView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        topView.addSubview(fadeView)
        fadeView.isHidden = false

        let horizontalFadeConst = NSLayoutConstraint.constraints(withVisualFormat: "H:|[view]|", options: NSLayoutConstraint.FormatOptions(), metrics: nil, views: ["view": fadeView])
        let verticalFadeConst = NSLayoutConstraint.constraints(withVisualFormat: "V:|[view]|", options: NSLayoutConstraint.FormatOptions(), metrics: nil, views: ["view": fadeView])
        topView.addConstraints(horizontalFadeConst + verticalFadeConst)

        // crop overlay
        let cropFrame = CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.width * (1 / cropRatio))
        cropView.frame = cropFrame
        cropView.layer.borderWidth = 1
        cropView.layer.borderColor = UIColor.white.cgColor
        cropView.backgroundColor = UIColor.clear
        topView.addSubview(cropView)

        // control buttons
        var cropCenterXMultiplier: CGFloat = 1.0
        if picker?.sourceType != .camera { //hide retake/cancel when using camera as camera has its own preview
            cancelButton.translatesAutoresizingMaskIntoConstraints = false
            cancelButton.setTitle(cancelButtonText, for: .normal)
            cancelButton.addTarget(self, action: #selector(cropCancel), for: .touchUpInside)
            bottomView.addSubview(cancelButton)
            let centerCancelXConst = NSLayoutConstraint(item: cancelButton, attribute: .centerX, relatedBy: .equal, toItem: bottomView, attribute: .centerX, multiplier: 0.5, constant: 0)
            let centerCancelYConst = NSLayoutConstraint(item: cancelButton, attribute: .centerY, relatedBy: .equal, toItem: bottomView, attribute: .centerY, multiplier: 1, constant: 0)
            bottomView.addConstraints([centerCancelXConst, centerCancelYConst])
            cropCenterXMultiplier = 1.5
        }
        cropButton.translatesAutoresizingMaskIntoConstraints = false
        cropButton.addTarget(self, action: #selector(cropDone), for: .touchUpInside)
        bottomView.addSubview(cropButton)
        let centerCropXConst = NSLayoutConstraint(item: cropButton, attribute: .centerX, relatedBy: .equal, toItem: bottomView, attribute: .centerX, multiplier: cropCenterXMultiplier, constant: 0)
        let centerCropYConst = NSLayoutConstraint(item: cropButton, attribute: .centerY, relatedBy: .equal, toItem: bottomView, attribute: .centerY, multiplier: 1, constant: 0)
        bottomView.addConstraints([centerCropXConst, centerCropYConst])
        
        self.view.bringSubviewToFront(bottomView)
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.cancelButton.setTitle(cancelButtonText, for: .normal)
        self.cropButton.setTitle(cropButtonText, for: .normal)
        
        if image == nil {
            self.dismiss(animated: true, completion: nil)
        }
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        maskFadeView()
        cropView.center = topView.center
        imageView.center = topView.center
    }
    
    private func maskFadeView() {
        let path = UIBezierPath(rect: cropView.frame)
        path.append(UIBezierPath(rect: fadeView.frame))
        let mask = CAShapeLayer()
        mask.fillRule = CAShapeLayerFillRule.evenOdd
        mask.path = path.cgPath
        fadeView.layer.mask = mask
    }

    //MARK: - button actions
    @objc func cropDone() {
        presenting = false
        if picker == nil {
            self.dismiss(animated: false, completion: {
                if self.autoClosePicker {
                    self.picker?.dismiss(animated: true, completion: nil)
                }
                self.delegate?.didCropImage(originalImage: self.image, croppedImage: self.cropImage)
            })
        } else {
            self.endAppearanceTransition()
            self.view.removeFromSuperview()
            self.removeFromParent()
            if self.autoClosePicker {
                self.picker?.dismiss(animated: true, completion: nil)
            }
            self.delegate?.didCropImage(originalImage: self.image, croppedImage: self.cropImage)
        }
    }
    
    @objc func cropCancel() {
        presenting = false
        if picker == nil {
            self.dismiss(animated: true, completion: nil)
        } else {
            self.endAppearanceTransition()
            self.view.removeFromSuperview()
            self.removeFromParent()
        }
    }

    //MARK: - gesture handling
    @objc func pinch(_ pinch: UIPinchGestureRecognizer) {
        if pinch.state == .began {
            orgWidth = imageView.bounds.width
            orgHeight = imageView.bounds.height
            pinchStart = pinch.location(in: self.view)
        }
        let scale = pinch.scale
        let height = max(orgHeight * scale, cropView.frame.height)
        let width = max(orgWidth * scale, cropView.frame.height / ratio)
        var fr = imageView.frame
        fr.size = CGSize(width: width, height: height)
        imageView.frame = fr
    }
    
    @objc func pan(_ pan: UIPanGestureRecognizer) {
        if pan.state == .began {
            panXStart = imageView.center.x
            panYStart = imageView.center.y
        } else {
            let trans = pan.translation(in: self.view)
            var point = imageView.center
            point.x = panXStart + trans.x
            point.y = panYStart + trans.y
            imageView.center = point
        }
    }

    //MARK: - cropping done here
    private func crop() -> UIImage? {
        guard let image = self.image else {
            return nil
        }
        let imageSize = image.size
        let width = cropView.frame.width / imageView.frame.width
        let height = cropView.frame.height / imageView.frame.height
        let x = (cropView.frame.origin.x - imageView.frame.origin.x) / imageView.frame.width
        let y = (cropView.frame.origin.y - imageView.frame.origin.y) / imageView.frame.height

        let cropFrame = CGRect(x: x * imageSize.width, y: y * imageSize.height, width: imageSize.width * width, height: imageSize.height * height)
        if let cropCGImage = image.cgImage?.cropping(to: cropFrame) {
            let cropImage = UIImage(cgImage: cropCGImage, scale: 1, orientation: .up)
            return cropImage
        }
        return nil
    }

    //MARK: - UIImagePickerControllerDelegates
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        presenting = false
        if delegate?.didCancel?() == nil {
            picker.dismiss(animated: true, completion: nil)
        }
    }
    
    var presenting = false
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard !presenting else {
            return
        }
        guard let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else {
            return
        }
        presenting = true
        self.image = image.fixOrientation()
        self.picker?.view.addSubview(self.view)
        self.view.constraintToFill(superView: self.picker?.view)
        self.picker?.addChild(self)
        self.willMove(toParent: self.picker)
        self.beginAppearanceTransition(true, animated: false)
    }
    
}

extension UIView {
    func constraintToFill(superView view: UIView?) {
        guard let view = view else {
            assertionFailure("superview is nil")
            return
        }
        self.translatesAutoresizingMaskIntoConstraints = false
        self.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        self.heightAnchor.constraint(equalTo: view.heightAnchor).isActive = true
        self.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        self.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    }
}
