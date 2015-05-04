//
//  WebViewController.m
//  Beacon Demo
//
//  Created by Severin Schoepke on 29/04/15.
//  Copyright (c) 2015 Shortcut Media AG. All rights reserved.
//

#import "WebViewController.h"

@interface WebViewController () <UIWebViewDelegate>

@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *backButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *forwardButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *loadingItem;

@end

@implementation WebViewController

- (void)setUrl:(NSURL *)url
{
    _url = url;
    
    if (self.webView) {
        // TODO: clear history
        [self loadURL:_url];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.webView.delegate = self;
    self.webView.hidden = YES;
    
    if (self.url) {
        [self loadURL:self.url];
    }
}

- (void)loadURL:(NSURL *)url
{
    if (![self.webView.request.URL isEqual:url]) {
        [self.webView stopLoading];
        [self.webView loadRequest:[NSURLRequest requestWithURL:url]];
    }
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [self updateToolbar];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (!self.webView.loading) {
        self.webView.hidden = NO;
    }
    
    [self updateToolbar];
}

#pragma mark - Toolbar

- (void)updateToolbar
{
    if (!self.webView.loading) {
        if ([self.toolbar.items containsObject:self.loadingItem]) {
            NSMutableArray *newItems = [NSMutableArray arrayWithArray:self.toolbar.items];
            [newItems removeObject:self.loadingItem];
            self.toolbar.items = newItems;
        };
    } else {
        if (![self.toolbar.items containsObject:self.loadingItem]) {
            NSMutableArray *newItems = [NSMutableArray arrayWithArray:self.toolbar.items];
            [newItems addObject:self.loadingItem];
            self.toolbar.items = newItems;
        };
    }
    
    self.backButton.enabled    = self.webView.canGoBack;
    self.forwardButton.enabled = self.webView.canGoForward;
}

- (IBAction)goBack:(id)sender {
    [self.webView goBack];
    [self updateToolbar];
}

- (IBAction)goForward:(id)sender {
    [self.webView goForward];
    [self updateToolbar];
}

@end
