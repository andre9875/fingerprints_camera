//
//  ViewController.swift
//  TestOpenCV
//
//  Created by Sandeep Mahajan on 18/09/23.
//

import UIKit
import Accelerate

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        if let inputImage = UIImage(named: "thumbGrayImg.png") {
            if let (realPart, imaginaryPart) = performDFT(on: inputImage) {
                // You can use these results for further analysis or processing
                let equalizedImage = histogramEqualization(realPart: realPart, imaginaryPart: imaginaryPart)
                
                // Now we have to perform binarization on the image
                let thresholdValue: UInt8 = 128
                let binaryImage = binarizeImage(image: equalizedImage!, threshold: thresholdValue)

                //let binaryImage = binarizeImage(image: inputImage, threshold: thresholdValue)

                // Perform thinning operation for extracting
                //let thinnedImage = thinning(image: binaryImage!)

                //Extract Minutiae from the thinned image
                //let minutiaeImage = extractMinutiae(image: thinnedImage!)
                let minutiaeImage = extractMinutiae(image: inputImage)
                
            }
        }
    }
    
    // MARK: - Step 1 - DFT
    // Function to perform DFT on a grayscale image
    func performDFT(on image: UIImage) -> ([Double], [Double])? {
        // Convert the UIImage to a grayscale CGImage
        guard let cgImage = image.cgImage,
              let pixelData = cgImage.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else {
                return nil
            }
            
        let width = cgImage.width
        let height = cgImage.height
        
        // Calculate the real and imaginary parts of the DFT at the origin
        var realPart: [Double] = Array(repeating: 0.0, count: width * height)
        var imaginaryPart: [Double] = Array(repeating: 0.0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let pixelValue = Double(data[y * width + x]) / 255.0
                realPart[y * width + x] += pixelValue
                imaginaryPart[y * width + x] += 0.0
            }
        }
        return (realPart, imaginaryPart)
    }
    
    
    // MARK: - Step 2 - Histogram Equalization
    // Function to perform histogram equalization on the magnitude of the DFT output
    func histogramEqualization(realPart: [Double], imaginaryPart: [Double]) -> UIImage? {
        // Calculate the magnitude of the DFT output
        var magnitude = [Double]()
        for i in 0..<realPart.count {
            let real = realPart[i]
            let imag = imaginaryPart[i]
            let mag = sqrt(real * real + imag * imag)
            magnitude.append(mag)
        }
        
        // Calculate the histogram of the magnitude
        var histogram = [Int](repeating: 0, count: 256)
        for value in magnitude {
            let intValue = Int(value * 255.0)
            histogram[min(max(intValue, 0), 255)] += 1
        }
        
        // Calculate the cumulative histogram
        var cumulativeHistogram = [Int](repeating: 0, count: 256)
        cumulativeHistogram[0] = histogram[0]
        for i in 1..<256 {
            cumulativeHistogram[i] = cumulativeHistogram[i - 1] + histogram[i]
        }
        
        // Calculate the mapping function
        var mapping = [UInt8](repeating: 0, count: 256)
        let totalPixels = magnitude.count
        for i in 0..<256 {
            let normalized = Double(cumulativeHistogram[i]) / Double(totalPixels)
            let mappedValue = UInt8(max(min(255.0 * normalized, 255.0), 0.0))
            mapping[i] = mappedValue
        }
        
        // Apply the mapping function to the magnitude
        var equalizedMagnitude = [UInt8](repeating: 0, count: magnitude.count)
        for i in 0..<magnitude.count {
            let intValue = Int(magnitude[i] * 255.0)
            equalizedMagnitude[i] = mapping[min(max(intValue, 0), 255)]
        }
        
        // Create a UIImage from the equalized magnitude
        let equalizedCGImage = CGImage(width: realPart.count,
                                       height: 1,
                                       bitsPerComponent: 8,
                                       bitsPerPixel: 8,
                                       bytesPerRow: realPart.count,
                                       space: CGColorSpaceCreateDeviceGray(),
                                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                       provider: CGDataProvider(data: NSData(bytes: equalizedMagnitude, length: equalizedMagnitude.count))!,
                                       decode: nil,
                                       shouldInterpolate: true,
                                       intent: .defaultIntent)
        
        return UIImage(cgImage: equalizedCGImage!)
    }
    
    // MARK: - Step 3 -  Binarization Of Image
    // Function to perform binarization on the enhanced image
    func binarizeImage(image: UIImage, threshold: UInt8) -> UIImage? {
        // Convert the input UIImage to a CGImage
        guard let cgImage = image.cgImage else {
            return nil
        }

        // Create a bitmap context to store the binary image
        let width = cgImage.width
        let height = cgImage.height
        let bitsPerComponent = 8
        let bytesPerRow = width
        let colorSpace = CGColorSpaceCreateDeviceGray()
        
        var bitmapData = [UInt8](repeating: 0, count: width * height)

        // Iterate through each pixel of the grayscale image and apply binarization
        for y in 0..<height {
            for x in 0..<width {
                
                //let pixelValue = cgImage.dataProvider?.data?.load(fromByteOffset: (y * width + x), as: UInt8.self) ?? 0
                let pixelData = cgImage.dataProvider!.data!
                let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
                let pixelValue = UInt8(data[y * width + x])
                
                if pixelValue >= threshold {
                    bitmapData[y * width + x] = 255
                } else {
                    bitmapData[y * width + x] = 0
                }
            }
        }

        // Create a bitmap context for the binary image
        let context = CGContext(data: &bitmapData,
                                width: width,
                                height: height,
                                bitsPerComponent: bitsPerComponent,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.none.rawValue)

        guard let binaryCGImage = context?.makeImage() else {
            return nil
        }

        // Create a UIImage from the binary CGImage
        let binaryImage = UIImage(cgImage: binaryCGImage)

        return binaryImage
    }

    // MARK: - Step 4  - Image thinning
    // Function to perform thinning (skeletonization) on a binary image
    func thinning(image: UIImage) -> UIImage? {
        // Convert the input UIImage to a CGImage
          guard let cgImage = image.cgImage else {
            return nil
        }

        // Create a bitmap context to store the binary image
        let width = cgImage.width
        let height = cgImage.height

        var pixels = [UInt8](repeating: 0, count: width * height)

        // Iterate through each pixel of the binary image and populate the pixel array
        for y in 0..<height {
            for x in 0..<width {
                //let pixelValue = cgImage.dataProvider?.data?.load(fromByteOffset: (y * width + x), as: UInt8.self) ?? 0
                
                let pixelData = cgImage.dataProvider!.data!
                let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
                let pixelValue = UInt8(data[y * width + x])
                
                pixels[y * width + x] = pixelValue
            }
        }

        // Perform Zhang-Suen thinning algorithm on the pixel array
        zhangSuenThinning(&pixels, width: width, height: height)

        // Create a bitmap context for the thinned image
        let context = CGContext(data: &pixels,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: width,
                                space: CGColorSpaceCreateDeviceGray(),
                                bitmapInfo: CGImageAlphaInfo.none.rawValue)

        guard let thinnedCGImage = context?.makeImage() else {
            return nil
        }

        // Create a UIImage from the thinned CGImage
        let thinnedImage = UIImage(cgImage: thinnedCGImage)

        return thinnedImage
    }

    // Function to apply Zhang-Suen thinning algorithm on a pixel array
    func zhangSuenThinning(_ pixels: inout [UInt8], width: Int, height: Int) {
        let neighborsOffsets = [(1, 0), (1, -1), (0, -1), (-1, -1), (-1, 0), (-1, 1), (0, 1), (1, 1)]
        var hasDeletion = true
        
        while hasDeletion {
            hasDeletion = false
            var toDelete = [(Int, Int)]()

            for y in 1..<height - 1 {
                for x in 1..<width - 1 {
                    let pixelValue = pixels[y * width + x]
                    
                    if pixelValue == 0 { // Only process foreground pixels (black)
                        continue
                    }
                    
                    var transitions = 0
                    var blackNeighbors = 0
                    
                    for offset in neighborsOffsets {
                        let nx = x + offset.0
                        let ny = y + offset.1
                        let neighborPixelValue = pixels[ny * width + nx]
                        
                        if neighborPixelValue == 0 {
                            blackNeighbors += 1
                        }
                        let index = (ny + offset.1) * width + (nx + offset.0)
                        if index >= 0 && index < 65536 {
                            if pixels[index] == 255 {
                                transitions += 1
                            }
                        }
                    }
                    
                    if blackNeighbors >= 2 && blackNeighbors <= 6 && transitions == 1 {
                        toDelete.append((x, y))
                    }
                }
            }
            
            for (x, y) in toDelete {
                pixels[y * width + x] = 0
                hasDeletion = true
            }
            
            toDelete.removeAll()
            
            for y in 1..<height - 1 {
                for x in 1..<width - 1 {
                    let pixelValue = pixels[y * width + x]
                    
                    if pixelValue == 0 { // Only process foreground pixels (black)
                        continue
                    }
                    
                    var transitions = 0
                    var blackNeighbors = 0
                    
                    for offset in neighborsOffsets {
                        let nx = x + offset.0
                        let ny = y + offset.1
                        let neighborPixelValue = pixels[ny * width + nx]
                        
                        if neighborPixelValue == 0 {
                            blackNeighbors += 1
                        }
                        let indexs = (ny + offset.1) * width + (nx + offset.0)
                        if indexs >= 0 && indexs < 65536{
                            if pixels[indexs] == 255 {
                                transitions += 1
                            }
                        }
                    }
                    
                    if blackNeighbors >= 2 && blackNeighbors <= 6 && transitions == 1 {
                        toDelete.append((x, y))
                    }
                }
            }
            
            for (x, y) in toDelete {
                pixels[y * width + x] = 0
                hasDeletion = true
            }
        }
    }
    
    // MARK: - Step 5 - Minutia Extration
    // Function to perform minutiae extraction using OpenCV
    func extractMinutiae(image: UIImage) -> UIImage? {
        let minutiaeImage = OpenCVWrapper.extractMinutiae(from: image)
        return minutiaeImage;
    }
    
    
    // MARK: - Step 6 - Methametical representation in form of multidimentional array of 0's and 1's
    // Function to convert the minutiae-extracted image into a unique bit array
    func convertToBitArray(image: UIImage) -> [UInt8]? {
        // Create an empty bit array
        var bitArray = [UInt8]()
        
        return bitArray
    }
}

