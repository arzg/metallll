#include <Cocoa/Cocoa.h>

int main()
{
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [NSApp run];
}
