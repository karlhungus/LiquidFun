//
//  LiquidFun.h
//  LiquidMetal
//
//  Created by Allen Tan on 11/16/14.
//  Copyright (c) 2014 White Widget Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifndef LiquidFun_Definitions
#define LiquidFun_Definitions

typedef struct Vector2D {
  float x;
  float y;
} Vector2D;


typedef struct Size2D {
  float width;
  float height;
} Size2D;

#endif

@interface LiquidFun : NSObject

+ (void)setGravity:(Vector2D)gravity;
+ (void)createWorldWithGravity:(Vector2D)gravity;
+ (void *)createEdgeBoxWithOrigin:(Vector2D)origin size:(Size2D)size;
+ (void *)createParticleSystemWithRadius:(float)radius dampingStrength:(float)dampingStrength gravityScale:(float)gravityScale density:(float)density;
+ (void)createParticleBoxForSystem:(void *)particleSystem position:(Vector2D)position size:(Size2D)size;
// add these after @interface and before @end
+ (int)particleCountForSystem:(void *)particleSystem;
+ (void *)particlePositionsForSystem:(void *)particleSystem;
+ (void)worldStep:(CFTimeInterval)timeStep velocityIterations:(int)velocityIterations positionIterations:(int)positionIterations;
+ (void)setParticleLimitForSystem:(void *)particleSystem maxParticles:(int)maxParticles;
+ (void)destroyWorld;
@end
