#include <efi.h>
#include <efilib.h>
#include <elf.h>

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
    InitializeLib(ImageHandle, SystemTable);    /* must be called at first */
    
    /* **********************************************************************
     * *                 Clears Existing Content on Screen                  *
     * ********************************************************************** */
    EFI_STATUS status = uefi_call_wrapper(SystemTable->ConOut->ClearScreen, 1, SystemTable->ConOut);
    if (EFI_ERROR(status)) {
        Print(L"[%d] Status: %r\r\n", __LINE__, status);
        return status;
    }

    /* **********************************************************************
     * *                       Disables the Watchdog                        *
     * ********************************************************************** */
    status = uefi_call_wrapper(SystemTable->BootServices->SetWatchdogTimer, 4, 0, 0, 0, NULL);
    if (EFI_ERROR(status)) {                    /* or UEFI will be rebooted */
        Print(L"[%d] Status: %r\r\n", __LINE__, status);
        return status;
    }

    /* **********************************************************************
     * *            Locates Kernel Executable in the File System            *
     * ********************************************************************** */
    EFI_GUID fs_proto_simple_guid = EFI_SIMPLE_FILE_SYSTEM_PROTOCOL_GUID;
    EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *fs_proto_simple = NULL;
    EFI_FILE_PROTOCOL *fs_proto = NULL, *kernel_file = NULL;
    status = uefi_call_wrapper(SystemTable->BootServices->LocateProtocol, 3, &fs_proto_simple_guid, NULL, (VOID **)&fs_proto_simple);
    if (EFI_ERROR(status)) {
        Print(L"[%d] Status: %r\r\n", __LINE__, status);
        return status;
    }

    status = uefi_call_wrapper(fs_proto_simple->OpenVolume, 2, fs_proto_simple, &fs_proto);
    if (EFI_ERROR(status)) {
        Print(L"[%d] Status: %r\r\n", __LINE__, status);
        return status;
    }

    status = uefi_call_wrapper(fs_proto->Open, 5, fs_proto, &kernel_file, L"cyan.exe", EFI_FILE_MODE_READ, 0);
    if (EFI_ERROR(status)) {                    /* trys to open the kernel file */
        Print(L"[%d] Status: %r; Failed to load the kernel.\r\n", __LINE__, status);
        return status;
    }


    /* **********************************************************************
     * *                Loads Kernel Executable into Memory                 *
     * ********************************************************************** */
    UINTN kernel_file_info_size = sizeof(EFI_FILE_INFO) + 64, kernel_file_size = 0;
    EFI_FILE_INFO *kernel_file_info = NULL;
    status = uefi_call_wrapper(SystemTable->BootServices->AllocatePool, 3, EfiLoaderData, kernel_file_info_size, (void **)&kernel_file_info);
    if (EFI_ERROR(status)) {                    /* gets the file size */
        Print(L"[%d] Status: %r\r\n", __LINE__, status);
        return status;
    }

    status = uefi_call_wrapper(kernel_file->GetInfo, 4, kernel_file, &gEfiFileInfoGuid, &kernel_file_info_size, kernel_file_info);
    if (EFI_ERROR(status)) {
        Print(L"[%d] Status: %r; Failed to load the kernel.\r\n", __LINE__, status);
        return status;
    }

    kernel_file_size = kernel_file_info->FileSize;

    status = uefi_call_wrapper(SystemTable->BootServices->FreePool, 1, kernel_file_info);
    if (EFI_ERROR(status)) {
        Print(L"[%d] Status: %r\r\n", __LINE__, status);
        return status;
    }

    /* **********************************************************************
     * *                Locates Instruction Pointer of Entry                *
     * ********************************************************************** */
    EFI_PHYSICAL_ADDRESS kernel_address = 0x100000;
    status = uefi_call_wrapper(SystemTable->BootServices->AllocatePages, 4, AllocateAnyPages, EfiLoaderData, (kernel_file_size + 0xFFF) >> 12, kernel_address);
    if (EFI_ERROR(status)) {                    /* write kernel to the memory */
        Print(L"[%d] Status: %r\r\n", __LINE__, status);
        return status;
    }
    
    status = uefi_call_wrapper(kernel_file->Read, 3, kernel_file, &kernel_file_size, kernel_address);
    if (EFI_ERROR(status)) {
        Print(L"[%d] Status: %r\r\n", __LINE__, status);
        return status;
    }

    status = uefi_call_wrapper(kernel_file->Close, 1, kernel_file);
    if (EFI_ERROR(status)) {
        Print(L"[%d] Status: %r\r\n", __LINE__, status);
        return status;
    }

    status = uefi_call_wrapper(fs_proto->Close, 1, fs_proto);
    if (EFI_ERROR(status)) {
        Print(L"[%d] Status: %r\r\n", __LINE__, status);
        return status;
    }

    Print(L"%lld\r\n", offsetof(Elf64_Ehdr, e_entry));

    for (int i = 0; i < kernel_file_size; ++i) {
        Print(L"0x%02x ", ((char *)kernel_address)[i]);
        if (((char *)kernel_address)[i] == 0xCF) {
            Print(L"\r\n Address: %p\r\n", kernel_address + i);
            break;
        }
    }

    Elf64_Ehdr *kernel_header = (Elf64_Ehdr *)kernel_address;
    void (*kmain)() = (void (*)())(kernel_header->e_entry);
    Print(L"\r\n %lld Entry: %p\r\n", sizeof(Elf64_Ehdr), kmain);

    /* **********************************************************************
     * *                Exit the Service and Jump to Kernel                 *
     * ********************************************************************** */
    UINTN mem_map_size = 0, mem_map_key = 0, mem_desc_size = 0;
    UINT32 mem_desc_ver = 0;
    EFI_MEMORY_DESCRIPTOR *mem_map_descs = NULL;
    status = uefi_call_wrapper(SystemTable->BootServices->GetMemoryMap, 5, &mem_map_size, mem_map_descs, &mem_map_key, &mem_desc_size, &mem_desc_ver);
    if (status != EFI_BUFFER_TOO_SMALL) {
        Print(L"[%d] Status: %r\r\n", __LINE__, status);
        return status;
    }

    /* If I call GetMemoryMap twice, mem_map_key is reported invalid, why? */
    status = uefi_call_wrapper(SystemTable->BootServices->ExitBootServices, 2, ImageHandle, mem_map_key);
    if (EFI_ERROR(status)) {
        Print(L"[%d] Status: %r\r\n", __LINE__, status);
        return status;
    }

    kmain();

    while (1);
    return EFI_SUCCESS;
}