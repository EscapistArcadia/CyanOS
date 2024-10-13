#include <efi.h>
#include <efilib.h>

/**
 * @brief The entry of the UEFI application and the first executed routines in the kernel.
 * We need not only to gather information and setup environment for the kernel, but also
 * load the kernel into the memory (correct address) to sstart the kernel.
 * 
 * @param ImageHandle The firmware allocated handle for the UEFI image.
 * @param SystemTable address of the UEFI system table, containing all services by UEFI.
 * @return 
 */
EFI_STATUS EFIAPI efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable) {
    EFI_STATUS status;

    InitializeLib(ImageHandle, SystemTable);    /* must be called at first */
    
    status = uefi_call_wrapper(SystemTable->ConOut->ClearScreen, 1, SystemTable->ConOut);
    if (EFI_ERROR(status)) {                    /* clears the existing content */
        return status;
    }

    status = uefi_call_wrapper(SystemTable->ConOut->OutputString, 2, SystemTable->ConOut, L"My first UEFI Bootloader Message!\n");
    if (EFI_ERROR(status)) {
        return status;
    }

    while (1);
    return EFI_SUCCESS;
}