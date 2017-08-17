//
//  OpenGLESView.m
//  OpenGLES02-着色器
//
//  Created by qinmin on 2017/2/9.
//  Copyright © 2017年 qinmin. All rights reserved.
//

#import "OpenGLESView.h"
#import <OpenGLES/ES2/gl.h>
#import "GLUtil.h"


@interface OpenGLESView ()
{
    CAEAGLLayer     *_eaglLayer;
    EAGLContext     *_context;
    GLuint          _colorRenderBuffer;
    GLuint          _frameBuffer;

    GLuint          _program;
    
    // CoreVideo
    CVOpenGLESTextureCacheRef _openGLESTextureCache;
    CVOpenGLESTextureRef _openGLESTexture;
}
@end

@implementation OpenGLESView

+ (Class)layerClass
{
    // 只有 [CAEAGLLayer class] 类型的 layer 才支持在其上描绘 OpenGL 内容。
    return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self setupLayer];
        [self setupContext];
        [self setupFrameAndRenderBuffer];
        [self setupGLProgram];
        [self setupOpenGLTextureCache];
        [self genVertexData];
    }
    return self;
}

#pragma mark - Setup
- (void)setupLayer
{
    _eaglLayer = (CAEAGLLayer*) self.layer;
    
    // CALayer 默认是透明的，必须将它设为不透明才能让其可见
    _eaglLayer.opaque = YES;
    
    // 设置描绘属性，在这里设置不维持渲染内容以及颜色格式为 RGBA8
    _eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
}

- (void)setupContext
{
    // 设置OpenGLES的版本为2.0 当然还可以选择1.0和最新的3.0的版本，以后我们会讲到2.0与3.0的差异，目前为了兼容性选择2.0的版本
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (!_context) {
        NSLog(@"Failed to initialize OpenGLES 2.0 context");
        exit(1);
    }
    
    // 将当前上下文设置为我们创建的上下文
    if (![EAGLContext setCurrentContext:_context]) {
        NSLog(@"Failed to set current OpenGL context");
        exit(1);
    }
}

- (void)setupFrameAndRenderBuffer
{
    glGenRenderbuffers(1, &_colorRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
    // 为 color renderbuffer 分配存储空间
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:_eaglLayer];
    
    glGenFramebuffers(1, &_frameBuffer);
    // 设置为当前 framebuffer
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    // 将 _colorRenderBuffer 装配到 GL_COLOR_ATTACHMENT0 这个装配点上
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER, _colorRenderBuffer);
}

- (void)setupGLProgram
{
    NSString *vertFile = [[NSBundle mainBundle] pathForResource:@"vert.glsl" ofType:nil];
    NSString *fragFile = [[NSBundle mainBundle] pathForResource:@"frag.glsl" ofType:nil];
    _program = createGLProgramFromFile(vertFile.UTF8String, fragFile.UTF8String);
    
    glUseProgram(_program);
}

- (void)setupOpenGLTextureCache
{
    CVReturn statuts = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault,
                                                    NULL,
                                                    _context,
                                                    NULL,
                                                    &_openGLESTextureCache);
    if (statuts != kCVReturnSuccess) {
        exit(0);
    }
}

#pragma mark - Clean
- (void)destoryRenderAndFrameBuffer
{
    glDeleteFramebuffers(1, &_frameBuffer);
    _frameBuffer = 0;
    glDeleteRenderbuffers(1, &_colorRenderBuffer);
    _colorRenderBuffer = 0;
}

#pragma mark - Vertex
- (void)genVertexData
{
    // 需要加static关键字，否则数据传输存在问题
    static GLfloat vertices[] = {
        -1.0f, -1.0f, 0.0f, 0.0f, 1.0f,
         1.0f, -1.0f, 0.0f, 1.0f, 1.0f,
         1.0f,  1.0f, 0.0f, 1.0f, 0.0f,
        -1.0f,  1.0f, 0.0f, 0.0f, 0.0f
    };
    
    GLuint vbo = createVBO(GL_ARRAY_BUFFER, GL_STATIC_DRAW, sizeof(vertices), vertices);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    
    GLint posSlot = glGetAttribLocation(_program, "position");
    glEnableVertexAttribArray(posSlot);
    glVertexAttribPointer(posSlot, 3, GL_FLOAT, GL_FALSE, 5*sizeof(GLfloat), NULL);
    
    GLint textureCoordSlot = glGetAttribLocation(_program, "textureCoord");
    glEnableVertexAttribArray(textureCoordSlot);
    glVertexAttribPointer(textureCoordSlot, 2, GL_FLOAT, GL_FALSE, 5*sizeof(GLfloat), NULL+3*sizeof(GLfloat));
}

#pragma mark - GLTexture
- (void)genTetureFromImage:(CVImageBufferRef)imageRef
{
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                _openGLESTextureCache,
                                                imageRef,
                                                NULL,
                                                GL_TEXTURE_2D,
                                                GL_RGBA,
                                                (GLsizei)CVPixelBufferGetWidth(imageRef),
                                                (GLsizei)CVPixelBufferGetHeight(imageRef),
                                                GL_BGRA,
                                                GL_UNSIGNED_BYTE,
                                                0,
                                                &_openGLESTexture);

    glBindTexture(GL_TEXTURE_2D, CVOpenGLESTextureGetName(_openGLESTexture));
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glUniform1i(glGetUniformLocation(_program, "image"), 0);

    if (_openGLESTexture) {
        CFRelease(_openGLESTexture);
        _openGLESTexture = NULL;
        CVOpenGLESTextureCacheFlush(_openGLESTextureCache, 0);
    }
}

#pragma mark - Render
- (void)renderImage:(CVImageBufferRef)imageRef
{
    glClearColor(1.0, 1.0, 1.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glViewport(0, 0, self.frame.size.width, self.frame.size.height);

    // Texure
    [self genTetureFromImage:imageRef];

    // Draw
    GLbyte indices[] = {0, 1, 2, 2, 3, 0};
    glDrawElements(GL_TRIANGLES, sizeof(indices), GL_UNSIGNED_BYTE, indices);
    
    //将指定 renderbuffer 呈现在屏幕上，在这里我们指定的是前面已经绑定为当前 renderbuffer 的那个，在 renderbuffer 可以被呈现之前，必须调用renderbufferStorage:fromDrawable: 为之分配存储空间。
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

@end
