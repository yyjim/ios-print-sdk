//
// Hewlett-Packard Company
// All rights reserved.
//
// This file, its contents, concepts, methods, behavior, and operation
// (collectively the "Software") are protected by trade secret, patent,
// and copyright laws. The use of the Software is governed by a license
// agreement. Disclosure of the Software to third parties, in any form,
// in whole or in part, is expressly prohibited except as authorized by
// the license agreement.
//

#import "HPPPPageRangeView.h"
#import "HPPPPageRange.h"
#import "UIColor+HPPPStyle.h"

@interface HPPPPageRangeView () <UITextFieldDelegate>

@property (strong, nonatomic) IBOutlet UIView *containingView;
@property (weak, nonatomic) IBOutlet UIView *smokeyView;
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (strong, nonatomic) NSMutableArray *buttons;
@property (strong, nonatomic) NSString *pageRange;

@end

@implementation HPPPPageRangeView

static NSString *kBackButtonText = @"⌫";
static NSString *kCheckButtonText = @"Done";//@"✔︎";
static NSString *kAllButtonText = @"ALL";

- (void)initWithXibName:(NSString *)xibName
{
    [super initWithXibName:xibName];
    
    self.textField.delegate = self;
}

- (void)dealloc
{
    [self removeButtons];
}

- (void)addButtons
{
    UIView *dummyView = [[UIView alloc] initWithFrame:CGRectMake(self.frame.size.width, self.frame.size.height, 1, 1)];
    self.textField.inputView = dummyView; // Hide keyboard, but show blinking cursor

    [self removeButtons];
    
    int buttonWidth = self.frame.size.width/4 + 1;
    int buttonHeight = .8 * buttonWidth;
    int yOrigin = self.frame.size.height - (4*buttonHeight);
    
    NSArray *buttonTitles = @[@"1", @"2", @"3", kBackButtonText, @"4", @"5", @"6", @",", @"7", @"8", @"9", @"-", @"0", kAllButtonText, kCheckButtonText];
    
    for( int i = 0, buttonOffset = 0; i<[buttonTitles count]; i++ ) {
        NSString *buttonText = [buttonTitles objectAtIndex:i];
        int row = (int)(i/4);
        int col = i%4;

        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setTitle:buttonText forState:UIControlStateNormal];
        [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [button layer].borderWidth = 1.0f;
        [button layer].borderColor = [UIColor lightGrayColor].CGColor;
        button.backgroundColor = [UIColor whiteColor];
        [button addTarget:self action:@selector(onButtonDown:) forControlEvents:UIControlEventTouchUpInside];

        if( [buttonText isEqualToString:[kAllButtonText copy]] ) {
            button.frame = CGRectMake(col*buttonWidth, yOrigin + (row*buttonHeight), buttonWidth*2, buttonHeight);
            buttonOffset++;
        } else {
            if( [buttonText isEqualToString:[kCheckButtonText copy]] ) {
                button.backgroundColor = [UIColor HPPPHPBlueColor];
                [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            }
            button.frame = CGRectMake((col+buttonOffset)*buttonWidth, yOrigin + (row*buttonHeight), buttonWidth, buttonHeight);
        }
        
        // Make sure we have at least a 1 pixel margin on the right side.
        if( button.frame.origin.x + button.frame.size.width >= self.frame.size.width ) {
            CGRect frame = button.frame;
            int diff = (button.frame.origin.x + button.frame.size.width) - self.frame.size.width;
            frame.size.width -= diff;
            button.frame = frame;
        }

        [self.containingView addSubview:button];
        
        [self.buttons addObject:button];
    }
}

- (void)removeButtons
{
    for( UIButton *button in self.buttons ) {
        [button removeFromSuperview];
    }
}

#pragma mark - HPPPEditView implementation

- (void)prepareForDisplay:(NSString *)initialText
{
    [self addButtons];

    if( NSOrderedSame == [initialText caseInsensitiveCompare:@"all"] ) {
        _pageRange = @"";
    } else {
        _pageRange = initialText;
    }
}

- (void)beginEditing
{
    UITextPosition *newPosition = [self.textField positionFromPosition:0 offset:self.textField.text.length];
    self.textField.selectedTextRange = [self.textField textRangeFromPosition:newPosition toPosition:newPosition];
    self.textField.text = self.pageRange;
    
    [self.textField becomeFirstResponder];
}

- (void)cancelEditing
{
    // do nothing;
    self.textField.text = self.pageRange;
}

- (void)commitEditing
{
    self.pageRange = [HPPPPageRange cleanPageRange:self.textField.text allPagesIndicator:kAllButtonText maxPageNum:self.maxPageNum];
    if( self.delegate  &&  [self.delegate respondsToSelector:@selector(didSelectPageRange:pageRange:)]) {
        [self.delegate didSelectPageRange:self pageRange:self.pageRange];
    }
}

#pragma mark - Button handler

- (IBAction)onButtonDown:(UIButton *)button
{
    
    if( [kBackButtonText isEqualToString:button.titleLabel.text] ) {
        [self replaceCurrentRange:@"" forceDeletion:TRUE];
    } else if( [kCheckButtonText isEqualToString:button.titleLabel.text] ) {
        
        if( self.delegate  &&  [self.delegate respondsToSelector:@selector(didSelectPageRange:pageRange:)]) {
            [self.delegate didSelectPageRange:self pageRange:[HPPPPageRange cleanPageRange:self.textField.text allPagesIndicator:kAllButtonText maxPageNum:self.maxPageNum]];
        }
        
    } else if( [kAllButtonText isEqualToString:button.titleLabel.text] ) {
        self.textField.text = [kAllButtonText copy];
        
    } else {
        if( [kAllButtonText isEqualToString:self.textField.text] ) {
            self.textField.text = @"";
        }
        
        [self replaceCurrentRange:button.titleLabel.text forceDeletion:FALSE];
    }
}

#pragma mark - Text scrubbing methods

- (NSRange) selectedRangeInTextView:(UITextField*)textView
{
    UITextPosition* beginning = textView.beginningOfDocument;
    
    UITextRange* selectedRange = textView.selectedTextRange;
    UITextPosition* selectionStart = selectedRange.start;
    UITextPosition* selectionEnd = selectedRange.end;
    
    const NSInteger location = [textView offsetFromPosition:beginning toPosition:selectionStart];
    const NSInteger length = [textView offsetFromPosition:selectionStart toPosition:selectionEnd];
    
    return NSMakeRange(location, length);
}

- (void) replaceCurrentRange:(NSString *)string forceDeletion:(BOOL)forceDeletion
{
    NSMutableString *text = [NSMutableString stringWithString:self.textField.text];
    
    NSRange selectedRange = [self selectedRangeInTextView:self.textField];
    UITextRange *selectedTextRange = [self.textField selectedTextRange];
    
    if( forceDeletion  &&  0 == selectedRange.length  &&  0 != selectedRange.location ) {
        selectedRange.location -= 1;
        selectedRange.length = 1;
    }
    
    [text deleteCharactersInRange:selectedRange];
    
    [text insertString:string atIndex:selectedRange.location];
    
    self.textField.text = text;
    
    if( forceDeletion  &&  1 == selectedRange.length ) {
        UITextPosition *newPosition = [self.textField positionFromPosition:selectedTextRange.start offset:-1];
        self.textField.selectedTextRange = [self.textField textRangeFromPosition:newPosition toPosition:newPosition];
    } else {
        UITextPosition *newPosition = [self.textField positionFromPosition:selectedTextRange.start offset:string.length];
        self.textField.selectedTextRange = [self.textField textRangeFromPosition:newPosition toPosition:newPosition];
    }
}


@end
