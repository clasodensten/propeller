''***************************************
''*  Memory Storage Management v2.0     *
''*  Branch: Heavyweight                * 
''*  Author: Brandon Nimon              *
''*  Created: 5 August, 2009            *
''*  Copyright (c) 2009 Parallax, Inc.  *
''*  See end of file for terms of use.  *  
''***********************************************************************************
''* Note that a lightweight version of the object exists. It removes storing of     *
''* strings, stacks, and arrays. It reduces the program size to about half of this  *
''* object. Download here: obex.parallax.com/objects/671/                           *
''*                                                                                 *
''* This object is designed to allow programmers (and/or end-users) to store        *
''* values to EEPROM, referenced by name rather than just a number. It is similar   * 
''* to a simple database system. The values can be stored in numerical byte, word,  *
''* or long values. Strings, arrays, and stacks can also be stored to the EERPOM,   *
''* but only in the "Heavyweight" and "Welterweight" versions of the object.        *
''* All of the values are created, edited, and retrieved with a simple name.        *
''*                                                                                 *
''* This is great for storing user-created settings or values that need to be       *
''* accessed at a later time with profile names or user entries. In the right       *
''* hands, it can be used for just about any EEPROM application.                    *
''*                                                                                 *
''* Added in v1.2 is check_edit_create for byte/word/long values. This makes        *
''* tracking existing values more unnecissary. The methods will create the value if *
''* it does not exist, and edit it if it does, but only if the value is different   *
''* than what is already stored in the EEPROM. These are the recommended methods to *
''* use to reduce headaches and over-usage of EEPROM erase/write cycles.            *
''*                                                                                 *
''* Added in v2.0, deletion renames values so the name and data space is not        *
''* wasted. When a new value of the same type is created, the system checks to see  *
''* if there is a deleted value that is the same size or larger, and uses that      *
''* space instead of using fresh space.                                             *
''*                                                                                 *
''* Storage scheme         Long 1         Long 2 (non-array)    Long 2 (array)      *
''*   of table:       Name  Size1 Type     Data  Size1 Size2     Data   Size2       *
''*                  $FF_FF  _FF   _FF    $FF_FF  _FF   _FF     $FF_FF  _FF_FF      *
''* Name and Data are EEPROM address locations. Size1 is size of current value      *
''* (name or data). Size2 is size of reserved space (if the size of the strings and *
''* arrays are changed and empty space is left unused). The lower WORD of the       *
''* second LONG is changed for arrays, since a 256 byte limit seemed very           *
''* restrictive for arrays. Strings longer than 255 bytes should be stored as       *
''* arrays to bypass the limitation. Access is slower if a shorter string replaces  *
''* the original (longer) one, as the read command will read all the bytes reserved *
''* for the array, even if they don't apply to the current item. This is why it is  *
''* important to include a terminating byte to all strings and track array sizes    *
''* externally (usually arrays are a constant length, due to memory constraints).   *
''*                                                                                 *
''* Data storage arrangement is a bit unique. The names and main data are stored in *
''* linear fashion. The table is indexed based on the value name, thus the table    *
''* is filled somewhat sporadically.                                                *
''*    info|table | name storage  |               data storage               end    *
''*      |*|-**--*|******---------|***************---------------------------|      *
''*   (*) represents stored data as the software is used                            *
''*   (-) represents free space                                                     *
''*   (|) represents memory addresses set in constants section                      *
''***********************************************************************************
''* Here is a list of the commonly used methods:                                    *
''*   init                               initialize the I2C device and this object  *
''*   create_byte/word/long              create a numeric value                     *
''*   create_str                         create a string                            *
''*   create_array                       create an array (or stack)                 *
''*   edit_byte/word/long                edit a stored numeric value                *
''*   check_edit_create_byte/word/long   edit or create numeric value               *
''*   edit_create_str/array              edit or create a string or array           *
''*   edit_array                         edit a stored array (or stack)             *
''*   rename                             edit name of stored value                  *
''*   get_dec                            get a stored numeric value                 *
''*   get_str                            get a stored string                        *
''*   get_array                          get a stored array (or stack)              *
''*   delete                             delete table value                         *
''*   is_set                             returns if value is stored or not          *
''*   get_name_list/next_name            get list of the name of stored values      *
''*   prep_/get_*_parts_array            get parts of array (for >255 byte storage) *
''***********************************************************************************
''
'' Notes:
''      Please post any bugs, feature requests, or just comments on the Obex page for
''        this object (http://obex.parallax.com/objects/493/) or PM Bobb Fwed on the
''        forum. 
''      Make sure the DATA values (in the CON section) do not encroach in the memory
''        space of the program (check using the F8 window). Use the Excel sheet that
''        came with the object to help you out.
''      This object can use both BASIC_I2C_Driver and PASM_I2C_Driver. The PASM version
''        is significantly faster, but uses an additional cog.
''      This object uses the Simple Numbers object. It only uses one method out of it,
''        so if you aren't using the Simple Numbers object elsewhere, you can save
''        yourself 100 or longs of programming space by copying the the needed method
''        into this object. (Or just compile using BST) 
''      Using a 64KB EEPROM and setting the start addresses (in CON) into the unused
''        section of the EEPROM will allow the values to stay even after an F11
''        reprogramming.
''      Memory addresses higher than 64K ($FFFF) cannot be used by this program.
''      Getting a value can return 0 (false) if certain criteria aren't met. This means
''        if the code using the get methods is looking for a numerical value or a
''        string, be aware that 0 may be returned on failure.
''      The length of a new value for an edited string cannot exceed the original size.
''        It is possible to store a long string, then replace it with a small one. The
''        original size of the string is reserved for future use by the same string.
''        Longer strings than the original will be truncated to the original's length.  
''      Names are case sensitive.
''      Names are truncated to name_size. The name is truncated by reference, meaning
''        the name at the address submitted will be altered. If this is undesired, be
''        sure to copy the name to a new "safe" location before passing to this object.      
''      When more than ~70% of the table is filled, response time to store new values
''        and access existing ones may increase significantly as it approaches 100%.
''      The read_multipage method stores read information (temporarily) in the upper
''        most portion of the RAM. Once accessed, values should be moved (with
''        bytemove) to a more permanent location. Also any other programs dependent on
''        the high bytes of the RAM may be affected. Stack space should also be
''        considered. At least 256 bytes should be left free (after program and stack
''        space) at the end of the RAM.
''      Strings can be stored as array, but the size of the array should be the length
''        of the string increased by one to allow for the terminating byte. If you use
''        create_str, you can still use prep_get_parts_array to access the string. This
''        is useful if the string is longer than 255 bytes.     
''
'' Changelog:
''      For full change log, read the ChangeLog.txt file in the ZIP from the OBEX.
''      v2.0.2 (February 18, 2011):
''              Added sort_names which will sort the names array in ascending
''                alphabetical order. It uses either insertion or shell sort algorithms
''                based on the length of the name list.
''              Added get_type_name_list which creates a name list based on value type.
''              Changed hard-coded type values to constants.
''
'' Future changes:                                                            
''      Attempt wear leveling (this is not likely to happen).                                                    
''
CON          

  {{== ALL start_* constants must be an address at the beginning of a page ==}}
  {{== Use supplied Excel file to help calculate these values. ==}}
  page_size   = 64              ' size of EEPROM sectors (pages) -- all values in comments below assume 64-byte page size -- this value cannot excede EEPROM page size, and cannot be less than 12, but could be a smaller multiple of actual page size, like 32 or 16
  store_info  = $69E0           ' table - 32
  start_table = $6A00           ' must start at beginning of a page
  start_names = $6C00           ' table + 512 (64 table entries), must be at least the length of a single page
  start_data  = $7000           ' names + 1024 (minimum 64 names -- and leaves space for 4096 bytes of values), must start at beginning of a page
  end_data    = $7FFF           ' end of data table, must end at end of a page
  table_size  = 128              ' must be equal (in longs) to the space between start_table and start_names (default is 128 == 512 bytes)
  name_size   = 16              ' maximum name length (keep LESS THAN page_size) (must be at least 8)

'===============================
  {{== Method Constants ==}}
  #1,TBYTE,TWORD,TLONG,TSTRING,TARRAY ' type constants, 1 = byte, 2 = word, 3 = long, 4 = string, 5 = array
  #0,NOTLIKE,LIKE               ' use MEM#LIKE or MEM#NOTLIKE when using the get_pattern_name_list method
  #0,ASC,DESC                   ' use MEM#ASC or MEM#DESC when using the sort_name method

  {{== EEPROM Constants ==}}
  BootPin     = 28              ' I2C Boot EEPROM SCL Pin
  EEPROM      = $A0             ' I2C EEPROM Device Address

  {{== Stack/Free ==}}
  _FREE       = 64              ' 256 bytes needed to use read_multipage
  _STACK      = 180             ' approximately 180 longs needed for stack
  
OBJ

  i2c   : "BASIC_I2C_Driver"    ' for read/write operations to EEPROM
  'i2c  : "PASM_I2C_Driver"     ' for read/write operations to EEPROM
  NUM   : "Simple_Numbers"     

VAR

  LONG table[table_size]        ' keep the table in RAM for fast access
  WORD names_ptr                ' next write location in EEPROM name space
  WORD data_ptr                 ' next write location in EEPROM data space
  WORD used_space               ' keep track of used space
  LONG names[table_size / 2]    ' keep list of name
  WORD name_list_size           ' store the size of the name list (for internal use)
  LONG list_ptr                 ' store list pointer
  BYTE val[page_size]           ' store page-size read values
  LONG array_res                ' stores resource for array recall (must be long due to overflow -- actual storave values are word maximum)
  LONG array_ptr                ' store array position (must be long due to overflow -- actual storave values are word maximum)
  WORD del_count                ' track number of all deleted items
  WORD del_longs                ' track number of deleted longs
  WORD del_words                ' track number of deleted words
  WORD del_bytes                ' track number of deleted bytes
  WORD del_strs                 ' track number of deleted strings
  WORD del_arrs                 ' track number of deleted arrays

PUB init | v[6], i
'' initiate i2c object and setup pointers for this object
'' returns true if EEPROM has already been initialized, false if it was not
  
  i2c.Initialize(BootPin)                                                       ' start i2c object                                                            
  bytemove(@v, read(store_info, 24), 24)                                        ' read setting values
     
  IF (v[0] == $81)                                                              ' if settings have been saved
    names_ptr := v.word[3]
    data_ptr := v.word[2]
    used_space := v[2]                                                          ' only uses lower word of this address
    del_count := v.word[6]
    del_longs := v.word[7]
    del_words := v.word[8]
    del_bytes := v.word[9]
    del_strs := v.word[10]
    del_arrs := v.word[11]
    longfill(@table, 0, table_size)                                             ' empty table

    REPEAT i FROM 0 TO constant(table_size - 1) STEP constant(page_size / 4)                  
      bytemove(@table[i], read(start_table + (i << 2), page_size), page_size)   ' fill table

    name_list_size := table_size >> 1                                           ' set to full table size, so it all gets cleared
    get_name_list                                                               ' update names list
    RETURN true
  ELSE                                                                          ' get and store default settings
    reset_all                                                                   ' clear table space out if not initialized
    RETURN false                                       
      
PUB create_byte (nameAddr, data)
'' create byte sized value in EEPROM
'' Type 1

  RETURN create(nameAddr, @data, 1, TBYTE)

PUB create_word (nameAddr, data)
'' create word sized value in EEPROM
'' Type 2

  RETURN create(nameAddr, @data, 2, TWORD)

PUB create_long (nameAddr, data)
'' create long sized value in EEPROM
'' Type 3

  RETURN create(nameAddr, @data, 4, TLONG)

PUB create_str (nameAddr, dataAddr)
'' create a entry with a string value

  RETURN create_arr_str(nameAddr, name_truncate(nameAddr), dataAddr, strsize(dataAddr) + 1, TSTRING, "S")

PUB create_array (nameAddr, dataAddr, data_size_bytes)
'' create an entry with a stack or array
'' var_size is the size of the array elements (1 = bytes, 2 = words, 4 = longs)
'' data_size_bytes is the size of the entire array, in BYTES

  RETURN create_arr_str(nameAddr, name_truncate(nameAddr), dataAddr, data_size_bytes, TARRAY, "A")

PUB edit_byte (nameAddr, newvalue)
'' edit byte sized value in EEPROM
'' Type 1

  RETURN edit(nameAddr, @newvalue, 1, TBYTE)

PUB edit_word (nameAddr, newvalue)
'' edit word sized value in EEPROM
'' Type 2

  RETURN edit(nameAddr, @newvalue, 2, TWORD)

PUB edit_long (nameAddr, newvalue)
'' edit long sized value in EEPROM
'' Type 3

  RETURN edit(nameAddr, @newvalue, 4, TLONG)

PUB check_edit_create_byte (nameAddr, newvalue)
'' check if a byte sized value in EEPROM needs to be edited or created
'' Type 1

  RETURN checkeditcreate(nameAddr, @newvalue, 1, TBYTE)

PUB check_edit_create_word (nameAddr, newvalue)
'' check if a word sized value in EEPROM needs to be edited or created
'' Type 2

  RETURN checkeditcreate(nameAddr, @newvalue, 2, TWORD)

PUB check_edit_create_long (nameAddr, newvalue)
'' check if a long sized value in EEPROM needs to be edited or created
'' Type 3

  RETURN checkeditcreate(nameAddr, @newvalue, 4, TLONG)

PUB edit_create_str (nameAddr, dataAddr)
'' simple method to test if a string needs to be edited or created

  IF (is_set(nameAddr))
    RETURN edit_str_arr(nameAddr, dataAddr, strsize(dataAddr) + 1, TSTRING)
  ELSE
    RETURN create_arr_str(nameAddr, name_truncate(nameAddr), dataAddr, strsize(dataAddr) + 1, TSTRING, "S") 

PUB edit_str (nameAddr, dataAddr) | v[2], ptr, i, max_str_size, data_str_size
'' edit the value of a string. new string will be truncated to length of original string (if longer)

  RETURN edit_str_arr(nameAddr, dataAddr, strsize(dataAddr) + 1, TSTRING)

PUB edit_create_array (nameAddr, dataAddr, data_size_bytes)
'' simple method to test if a stack or array needs to be edited or created

  IF (is_set(nameAddr))
    RETURN edit_str_arr(nameAddr, dataAddr, data_size_bytes, TARRAY)
  ELSE
    RETURN create_arr_str(nameAddr, name_truncate(nameAddr), dataAddr, data_size_bytes, TARRAY, "A")

PUB edit_array (nameAddr, dataAddr, data_size_bytes)
'' edit the value of a stack or array. new array will be truncated to length of original array (if longer)

  RETURN edit_str_arr(nameAddr, dataAddr, data_size_bytes, TARRAY)

PUB get_byte (nameAddr)
'' retrieve byte sized value from EEPROM
'' Type 1

  RETURN get(nameAddr, 1, TBYTE)
                         
PUB get_word (nameAddr)
'' retrieve word sized value from EEPROM
'' Type 2

  RETURN get(nameAddr, 2, TWORD)

PUB get_long (nameAddr)
'' retrieve long sized value from EEPROM
'' Type 3

  RETURN get(nameAddr, 4, TLONG)

PUB get_dec (nameAddr) | v[2], dataAddr
'' returns numerical value regaurdless of size (byte, word, or long)

  IF (getaddr(nameAddr, @v) <> -1)                                              ' if current name exists
    IF (v.byte[0] > TLONG)                                                      ' check that type matches
      RETURN false               

    dataAddr := v.word[3]
    CASE (v.byte[0])                                                            
      TBYTE: RETURN byte[read(dataAddr, 1)]
      TWORD: RETURN word[read(dataAddr, 2)]
      TLONG:
        bytemove(@v, read(dataAddr, 4), 4)
        RETURN v
      OTHER: RETURN false        
  ELSE                                  
    RETURN false  

PUB get_str (nameAddr) | v[2]
'' return address of stored string value
'' string must be less than 256 bytes (use prep_get_parts_array instead)

  IF (getaddr(nameAddr, @v) <> -1)                                              ' if current name exists 
    IF (v.byte[0] <> TSTRING)                                                   ' check that type matches
      RETURN false  
                                    
    RETURN read_multipage(v.word[3], v.byte[5])  
  ELSE                                  
    RETURN false

PUB get_array (nameAddr) | v[2]
'' return address of stored stack or array
'' array must be less than 256 bytes (use prep_get_parts_array instead)

  IF (getaddr(nameAddr, @v) <> -1)                                              ' if current name exists
    IF (v.byte[0] <> TARRAY)                                                    ' check that type matches
      RETURN false  
                                    
    RETURN read_multipage(v.word[3], v.word[2])  
  ELSE                                  
    RETURN false

PUB prep_get_parts_array (nameAddr) | v[2]
'' setyp resource to use with get_*_parts_array 

  IF (getaddr(nameAddr, @v) <> -1)                                              ' if current name exists
    IF (v.byte[0] <> TARRAY)                                                    ' check that type matches
      RETURN false

    array_ptr := 0
    array_res := v[1] 
                                    
    RETURN true  
  ELSE                                  
    RETURN false

PUB get_next_parts_array (element_size) : data
'' return next value of array (requires prep_get_parts_array to be called before first use)
'' element_size is bytes of array elements 1 = byte, 2 = word, 4 = long

  IF (array_ptr < array_res.word[0]) 
    bytemove(@data, read_multipage(array_res >> 16 + array_ptr, element_size), element_size)
    array_ptr += element_size
  ELSE
    RETURN false  

PUB get_prev_parts_array (element_size) : data
'' return previous value of array (requires prep_get_parts_array and get_next_parts_array to be called before first use)
'' element_size is bytes of array elements 1 = byte, 2 = word, 4 = long

  IF ((array_ptr -= element_size) => 0)     
    bytemove(@data, read_multipage(array_res >> 16 + array_ptr, element_size), element_size)
  ELSE
    array_ptr += element_size
    RETURN false

PUB set_array_pointer (location, element_size)
'' puts array pointer at specified location to retrieve array elements at differnt parts of the array that has been "prepped"
'' return "corrected" byte number (within the determined range)
'' location starts at 0

  array_ptr := ((location << (element_size >> 1)) #> 0) <# array_res.word[0]    ' set array pointer, force location into correct range
  RETURN array_ptr >> (element_size >> 1)                                       ' the ">> (x >> 1)" and "<< (x >> 1)" is a quick divide or mutliply if divider/multiplier is 4, 2, or 1

PUB get_array_pointer (element_size)
'' return current array pointer location

  RETURN array_ptr >> (element_size >> 1)

PUB rename (nameAddr, newnameAddr) | v[2], table_ptr, ptr, name_str_size, name_loc
'' edit the name of a value. new name will be stored in a new name space location
'' old table entry is removed and new table entry is added with new information

  IF ((ptr := getaddr(nameAddr, @v)) <> -1)                                     ' if current name exists
    name_str_size := name_truncate(newnameAddr)
    name_loc := v[0] >> 16                                                      ' get location of next new name location                             
      
    IF ((table_ptr := setaddr(newnameAddr)) == -1)                              ' get new name location 
      RETURN false
     
    write(name_loc, newnameAddr, name_str_size)                                 ' write new name
     
    v[0] := name_loc << 16 + name_str_size << 8 + v.byte[0]                       
    'v[1] := data_ptr << 16 + size << 8 + size                                  ' information just carried over from previous table value                            
    write(table_ptr << 2 + start_table, @v, 8)                                  ' write table info
     
    longmove(@table[table_ptr], @v, 2) 
    longfill(@table[ptr], 0, 2)
              
    write(start_table + ptr << 2, @table[ptr], 8)                               ' errase old EEPROM table with empty v variable

    tsort(ptr)                                                                  ' sort table to compensate for collided entries
            
    RETURN true       
  ELSE                                                              
    RETURN false

PUB delete (nameAddr) | v[3], tmp, delname[2]
'' Delete by renaming. This way, the space can be reused later

  IF (getaddr(nameAddr, @v) <> -1)                                              ' if current name exists
    byte[@delname][0] := "~"                                                    ' set first byte as tilde
    CASE v.byte[0]                                                              ' set second byte, it represents type of value
      TBYTE:
        tmp := del_bytes
        byte[@delname][1] := "B"
      TWORD:
        tmp := del_words
        byte[@delname][1] := "W"
      TLONG:
        tmp := del_longs
        byte[@delname][1] := "L"
      TSTRING:
        tmp := del_strs
        byte[@delname][1] := "S"
      TARRAY:
        tmp := del_arrs
        byte[@delname][1] := "A" 
     
    bytemove(@delname + 2, NUM.decx(tmp, 5), 5)                                 ' set next 5 bytes as zero padded number
    byte[@delname][7] := 0
    IF (rename(nameAddr, @delname))                                             ' don't remove the value, rename it for later use
      
      CASE v.byte[0]                                                            ' add to the deletion count based on the type of the value                                        
        TBYTE: del_bytes++
        TWORD: del_words++
        TLONG: del_longs++
        TSTRING: del_strs++
        TARRAY: del_arrs++

      'v[0] := --used_space                                                               
      v.word[0] := ++del_count                                                  ' add to the overall deletetion count
      v.word[1] := del_longs 
      v.word[2] := del_words 
      v.word[3] := del_bytes 
      v.word[4] := del_strs 
      v.word[5] := del_arrs 
      
      write(constant(store_info + 12), @v, 12)                                  ' write new deletion count to EEPROM
      RETURN true
    ELSE
      RETURN false
  ELSE
    RETURN false

PUB is_set (nameAddr)
'' return if a value by provided name is already set

  IF (setaddr(nameAddr) == -1)                                                  ' if current name exists
    RETURN true
  RETURN false

PUB get_type (nameAddr) | v[2]
'' return the type of value
'' 1 = byte   (MEM#TBYTE)
'' 2 = word   (MEM#TWORD)
'' 3 = long   (MEM#TLONG)
'' 4 = string (MEM#TSTRING)
'' 5 = array  (MEM#TARRAY)

  IF (getaddr(nameAddr, @v) <> -1)                                              ' if current name exists
    RETURN v.byte[0]
  ELSE
    RETURN false  

PUB get_size (nameAddr) | v[2]
'' return current size (in bytes) of a value

  IF (getaddr(nameAddr, @v) <> -1)                                              ' if current name exists
    IF (v.byte[0] <> TARRAY)
      RETURN v.byte[5]                                                          ' most types' size
    ELSE
      RETURN v.word[2]                                                          ' array's size
  ELSE
    RETURN false

PUB get_reserved_size (nameAddr) | v[2]
'' return reserved size (in bytes) of a value
'' this value can only different from get_size when using a string 

  IF (getaddr(nameAddr, @v) <> -1)                                              ' if current name exists
    IF (v.byte[0] <> TARRAY)
      RETURN v.byte[4]                                                          ' most types' size
    ELSE
      RETURN v.word[2]                                                          ' array's size
  ELSE
    RETURN false

PUB get_freetableentries
'' return number of free entries (free table space / 8)

  RETURN (table_size >> 1) - used_space

PUB get_freenamespace
'' return number of free bytes of names space

  RETURN start_data - names_ptr

PUB get_freedataspace
'' return number of free bytes of data space

  RETURN end_data - data_ptr

PUB get_usedtablespace
'' returns number of table space bytes used

  RETURN used_space

PUB get_usednamespace
'' returns number of name space bytes exhausted (used or wasted due to spacing)

  RETURN names_ptr - start_names
  
PUB get_useddataspace
'' returns number of data bytes exhausted (used or wasted due to spacing)

  RETURN data_ptr - start_data

PUB get_delete_count
'' return the number of deleted items (to represent the number of available spaces)

  RETURN del_count

PUB get_name_list : entries | i
'' return number of stored values (excluding deleted), gather address list of names
'' also it updates names list (for use with next_name)
'' this method is slower than get_full_name_list because it checks the first character of each name

  longfill(@names, 0, name_list_size)                                           ' reset existing list
  REPEAT i FROM 0 TO table_size - 1 STEP 2                                      ' cycle through entire table
    IF (table[i] <> 0)  
      IF (byte[read(table[i] >> 16, 1)] <> "~")                                 ' make sure entry is not "deleted"
        names[entries++] := table[i]                                            ' add to name list

  name_list_size := entries                                                     ' store name_list_size for later use
  list_ptr := 0                                                                 ' reset point to start from beginning

PUB get_full_name_list : entries | i
'' return number of stored values (including deleted), gather address list of names
'' also it updates names list (for use with next_name)

  longfill(@names, 0, name_list_size)                                           ' reset existing list
  REPEAT i FROM 0 TO table_size - 1 STEP 2                                      ' cycle through entire table
    IF (table[i] <> 0)
      names[entries++] := table[i]                                              ' add to name list

  name_list_size := entries                                                     ' store name_list_size for later use
  list_ptr := 0                                                                 ' reset point to start from beginning
 
PUB get_pattern_name_list (likeornot, patternAddr) : entries | i, tmp
'' return number of stored values matching a wild card pattern, use asterisk (*) as wild card
'' Use MEM#LIKE or MEM#NOTLIKE for likeornot, this is used for returning a matching pattern, or a non-matching pattern. 
'' This method updates names list (for use with next_name)
'' NOTICE: this method calls match_pattern which is a recursive function, long patterns could
''   use a significant amount of STACK space
 
  longfill(@names, 0, name_list_size)                                           ' reset existing list
  REPEAT i FROM 0 TO table_size - 1 STEP 2                                      ' cycle through entire table
    IF (table[i] <> 0)
      tmp := table[i]
      tmp := read(table[i] >> 16, tmp.byte[1])                                  ' get name from EEPROM
      IF (likeornot == LIKE)
        IF (match_pattern(tmp, patternAddr))                                    ' if pattern is found
          names[entries++] := table[i]                                          ' add to name list
      ELSE                                   
        IF NOT(match_pattern(tmp, patternAddr))                                 ' if pattern is not found
          names[entries++] := table[i]                                          ' add to name list

  name_list_size := entries                                                     ' store name_list_size for later use
  list_ptr := 0                                                                 ' reset point to start from beginning

PUB get_type_name_list (type) : entries | i, tmp
'' return number of stored values of a specific type
'' Types: MEM#TBYTE = byte, MEM#TWORD = word, MEM#TLONG = long, MEM#TSTRING = string, MEM#TARRAY = array
'' This method updates names list (for use with next_name)

  longfill(@names, 0, name_list_size)                                           ' reset existing list
  REPEAT i FROM 0 TO table_size - 1 STEP 2                                      ' cycle through entire table
    IF (table[i] <> 0)
      tmp := table[i]
      IF (tmp.byte[0] == type)
        names[entries++] := table[i]

  name_list_size := entries                                                     ' store name_list_size for later use
  list_ptr := 0                                                                 ' reset point to start from beginning

PUB sort_names (asc_desc)
'' sort the name list alphabetically
'' Call this after calling the desired get_*name_list and before calling next_/prev_name
'' This is quite slow, it is recommended to use the PASM I2C if you use this method, It makes this function
''   run about 5 times faster, which is very significant when there are more than a few names.
'' insertion sort is fast for small arrays, shell sort is fast for long arrays, so we use both.

  IF (name_list_size > 50)
    shellsort1(@names, name_list_size)
  ELSE
    insertionsort1(@names, name_list_size)
  RETURN true

PUB next_name | tmp
'' return current name in list, then increase name pointer

  IF (list_ptr < name_list_size)                                                ' check value is in range
    tmp := names[list_ptr++]
    RETURN read(tmp >> 16, tmp.byte[1])                                         ' read name and return address
  ELSE
    RETURN false

PUB prev_name | tmp
'' return previous name in list

  IF (--list_ptr => 0)                                                          ' check value is in range
    tmp := names[list_ptr]
    RETURN read(tmp >> 16, tmp.byte[1])                                         ' read name and return address
  ELSE
    list_ptr++                                                                  ' prevent roll over into another memory section
    RETURN false

PUB set_name_pointer (location)
'' puts name pointer at specified location to retrieve names at differnt parts of the last called name list
'' return "corrected" pointer number (within the determined range)
'' maximum value is based on last get_*name_list
'' location starts at 0

  RETURN list_ptr := (location #> 0) <# name_list_size                          ' set name pointer, force location into correct range 

PUB reset_all | i, v[6]
'' Errases all stored EEPROM and RAM tables. Resets pointers.
'' Gets set back as if it were the first time this program was ran (but names and
'' data is left unaltered -- only tables are errased).
  
  v[0] := $81
  v[1] := (names_ptr := start_names) << 16 + (data_ptr := start_data)
  v[2] := used_space := 0
  v[3] := del_longs := del_count := 0
  v[4] := del_bytes := del_words := 0
  v[5] := del_arrs := del_strs := 0 
  write(store_info, @v, 24)
   
  longfill(@names, 0, constant(table_size / 2))                   
  longfill(@table, 0, table_size)
  
  REPEAT i FROM 0 TO constant(table_size - 1) STEP constant(page_size / 4)                  
    write(start_table + (i << 2), @table, page_size)

PUB write_multipage (ptr, dataAddr, size) | i
'' write an array (that spans more than one page) to EEPROM over multiple pages 

  i := page_size - ptr // page_size
  IF (size =< i)                                                                ' if amount of info is less than what's left in this page
    write(ptr, dataAddr, size)
    RETURN true
  
  write(ptr, dataAddr, i) 
  size -= i                                                                     ' remaining data
  REPEAT
    IF (size =< page_size)
      write(ptr + i, dataAddr + i, size)
      QUIT
    ELSE
      IF (write(ptr + i, dataAddr + i, page_size))
        i += page_size
        size -= page_size
      ELSE
        RETURN false

  RETURN true

PUB read_multipage (ptr, size) : mem_addr | i
'' read an array (that spans more than one page) from EEPROM, store it in highest location possible in RAM

  IF (size =< $FF)
    i := page_size - ptr // page_size                                           ' determine bytes to end of page
    mem_addr := $7FFF - size                                                    ' start address
    IF (size =< i)
      bytemove(mem_addr, read(ptr, size), size)
      RETURN  
     
    bytemove(mem_addr, read(ptr, i), i)                                         ' move to lowest portion of the highest location in RAM
    size -= i
    ptr += i                                                                    ' remaining string size
    REPEAT
      IF (size =< page_size)
        bytemove($7FFF - size, read(ptr, size), size)                           ' read the last of the info
        QUIT
      ELSE
        bytemove($7FFF - size, read(ptr, page_size), page_size)                 ' read a page of the info
        ptr += page_size
        size -= page_size
  ELSE
    RETURN false 

PUB write (addr, valueAddr, size) | time
'' write page to EEPROM with watchdog  

  IF i2c.WritePage(BootPin, EEPROM, addr, valueAddr, size)
    RETURN false
  time := cnt
  repeat while i2c.WriteWait(BootPin, EEPROM, addr)                             ' wait for watchdog
    if cnt - time > clkfreq / 10
      RETURN false

  RETURN true 
 
PUB read (addr, size)
'' read page from EEPROM, return address of value
                          
  IF i2c.ReadPage(BootPin, EEPROM, addr, @val, size)
    RETURN false                     

  RETURN @val

PRI create (nameAddr, dataAddr, size, type) | v[2], name_str_size, table_ptr, tmp, delname[2]
'' create an entry with an integer value
'' this has been left as PUB to allow custom entries to be created 

  name_str_size := name_truncate(nameAddr)

  IF (del_count > 0)
    CASE type                                                                   ' set second byte, it represents type of value
      TBYTE:
        tmp := del_bytes - 1
        byte[@delname][1] := "B"
      TWORD:
        tmp := del_words - 1
        byte[@delname][1] := "W"
      TLONG:
        tmp := del_longs - 1
        byte[@delname][1] := "L" 

    IF (tmp => 0)                                                               ' if a deleted item exists in the correct type
      byte[@delname][0] := "~"                                                  ' set first byte as tilde
      bytemove(@delname + 2, NUM.decx(tmp, 5), 5)                               ' set next 5 bytes as zero padded number
      byte[@delname][7] := 0
      IF (rename(@delname, nameAddr))                                           ' change the name to the new name
        IF (edit(nameAddr, dataAddr, size, type))                               ' edit the value
          CASE type                                                             ' set second byte, it represents type of value
            TBYTE: del_bytes--        
            TWORD: del_words--
            TLONG: del_longs--
       
          'v[0] := ++used_space                                                               
          v.word[0] := --del_count                                              ' reduce the overall deletetion count
          v.word[1] := del_longs 
          v.word[2] := del_words 
          v.word[3] := del_bytes 
        
          write(constant(store_info + 12), @v, 8)                               ' write new deletion count and used_space count to EEPROM
       
          RETURN true
        ELSE
          rename(nameAddr, @delname)                                            ' if editing fails, change the name back, then continue as normal

  ' if.. no more table space left         end of name storage area           end of data storage space         name has already been used: fail
  IF (get_freetableentries =< 0) OR (names_ptr + name_size > start_data) OR (data_ptr + size > end_data) OR ((table_ptr := setaddr(nameAddr)) == -1)                                   '  
    RETURN false

  write(names_ptr, nameAddr, name_str_size)                                     ' write name

  data_ptr := storage_fault(data_ptr, size)                                     ' get location of next data location                                  

  write(data_ptr, dataAddr, size)                                               ' write data
                                                
  v[0] := names_ptr << 16 + name_str_size << 8 + type                           ' name location in upper word, data location in lower word
  v[1] := data_ptr << 16 + size << 8 + size                                     ' name size in byte[3], data size in byte[2] and byte[1], data type in byte[0]
  write(table_ptr << 2 + start_table, @v, 8)                                    ' write table info

  names_ptr += name_size                                                        ' move pointer
  data_ptr += size                                                              ' move pointer

  longmove(@table[table_ptr], @v, 2)

  v[0] := names_ptr << 16 + data_ptr
  v[1] := ++used_space
  write(constant(store_info + 4), @v, 8)

  RETURN true                                                                   ' return successful

PRI create_arr_str (nameAddr, name_str_size, dataAddr, data_size_bytes, type, letter) | v[2], table_ptr, i, ren, delname[2], delname2[2]
'' create a new value, specifically for values of an undefined length
'' check to see if there is a compatible deleted value, if there is, rename it to the new created value

  IF ((letter == "S" AND del_strs > 0) OR (letter == "A" AND del_arrs > 0))
    byte[@delname][0] := byte[@delname2][0] := "~"                              ' set first byte as tilde
    byte[@delname][1] := byte[@delname2][1] := letter
    byte[@delname][7] := byte[@delname2][7] := 0

    ren := 0
    REPEAT i FROM 0 TO del_arrs - 1
      bytemove(@delname + 2, NUM.decx(i, 5), 5)                                 ' set next 5 bytes as zero padded number
      IF NOT(ren)
        IF (get_reserved_size(@delname) => data_size_bytes)         
          IF (rename(@delname, nameAddr))                                       ' change the name to the new name
            IF (edit_str(nameAddr, dataAddr))                                   ' edit the value
              ren := -1                                                         ' set marker to rename all greater named strings
            ELSE
              rename(nameAddr, @delname)                                        ' if editing fails, change the name back, then continue as normal
      ELSE
        bytemove(@delname2 + 2, NUM.decx(i + 1, 5), 5)                          ' set next 5 bytes as zero padded number
        rename(@delname2, @delname)
    IF (ren)
      v.word[0] := --del_count                                                  ' reduce the overall deletetion count
      v.word[1] := del_longs
      write(constant(store_info + 12), @v, 4)                                   ' write new deletion count and used_space count to EEPROM
      IF (letter == "S")              
        v.word[0] := --del_strs                                                 ' reduce the deletetion count
        v.word[1] := del_arrs
      ELSE       
        v.word[0] := del_strs                                                   
        v.word[1] := --del_arrs                                                 ' reduce the deletetion count
      write(constant(store_info + 20), @v, 4)                                   ' write new deletion count and used_space count to EEPROM
      RETURN true

  ' if.. no more table space left         end of name storage area                end of data storage space              if name has already been used: fail
  IF (get_freetableentries =< 0) OR (names_ptr + name_size > start_data) OR (data_ptr + data_size_bytes > end_data) OR ((table_ptr := setaddr(nameAddr)) == -1)
    RETURN false                        
  
  write(names_ptr, nameAddr, name_str_size)                                     ' write name

  write_multipage(data_ptr, dataAddr, data_size_bytes)                          ' write data

  v[0] := names_ptr << 16 + name_str_size << 8 + type
  IF (type == TARRAY)
    v[1] := data_ptr << 16 + data_size_bytes                   
  ELSE                              
    v[1] := data_ptr << 16 + data_size_bytes << 8 + data_size_bytes
  write(table_ptr << 2 + start_table, @v, 8)                                    ' write table info

  names_ptr += name_size                                                        ' move pointer                                      
  data_ptr += data_size_bytes                                                   ' move pointer

  longmove(@table[table_ptr], @v, 2)  

  v[0] := names_ptr << 16 + data_ptr
  v[1] := ++used_space
  write(constant(store_info + 4), @v, 8)

  RETURN true
  
PRI edit (nameAddr, newvAddr, size, type) | v[2]
'' edit a numerical value
'' this has been left as PUB to allow custom entries to be edited
  
  IF (getaddr(nameAddr, @v) <> -1)                                              ' if current name exists
    IF (v.byte[0] <> type)                                                      ' check that type matches
      RETURN false

    write(v.word[3], newvAddr, size)
    RETURN true
  ELSE                                  
    RETURN false

PRI checkeditcreate (nameAddr, newvAddr, size, type) | v[2], dataAddr
'' Checks for existing value, if it doesn't exist, it creates it, if it does exist, it checks if
'' current value is different than the new value before writing to EEPROM.
'' The purpose of this is to reduce the number of times the EEPROM is written to and to reduce
'' confusion of messing with create and edit
'' this has been left as PUB to allow custom entries to be edited

  IF (getaddr(nameAddr, @v) <> -1)                                              ' if current name exists
    IF (v.byte[0] <> type)                                                      ' check that type matches 
      RETURN false

    dataAddr := v.word[3]
    CASE type
      TBYTE:
        IF (byte[read(dataAddr, 1)] <> byte[newvAddr])                          ' if new value does not equal current value
          RETURN write(dataAddr, newvAddr, size)                                ' write the new value
        RETURN true
      TWORD:
        IF (word[read(dataAddr, 2)] <> word[newvAddr])                          ' if new value does not equal current value
          RETURN write(dataAddr, newvAddr, size)                                ' write the new value                                      
        RETURN true
      TLONG:
        bytemove(@v, read(dataAddr, 4), 4)                                      ' store long value in v. Not sure why this is necisary, but it is for longs
        IF (v <> long[newvAddr])                                                ' if new value does not equal current value
          RETURN write(dataAddr, newvAddr, size)                                ' write the new value
        RETURN true 
    
  RETURN create(nameAddr, newvAddr, size, type)                                 ' create value

PRI edit_str_arr (nameAddr, dataAddr, data_size_bytes, type) | v[2], ptr, i, max_size
'' edit contents of strings and arrays

  IF ((ptr := getaddr(nameAddr, @v)) <> -1)                                     ' if current name exists
    IF (v.byte[0] <> type)                                                      ' check that type matches
      RETURN false

    IF (type == TARRAY)
      max_size := v.word[2]                                                       
    ELSE
      max_size := v.byte[4]
     
    IF (data_size_bytes > max_size)
      IF (type == TSTRING)
        write_multipage(v.word[3], dataAddr, max_size - 1)                      ' overwrite with maximum amount of info
        i := 0                                                                  ' need value that is definately 0, next line needs address of such a value
        write(v.word[3] + max_size, @i, 1)                                      ' terminate with 0 (just in case)
      ELSE
        write_multipage(v.word[3], dataAddr, max_size) 
    ELSE
      write_multipage(v.word[3], dataAddr, data_size_bytes)

    table[ptr + 1] := v[1]                                                      ' update RAM table                                                          
    write((ptr << 2) + start_table + 4, @v[1], 4)                               ' write table info

    RETURN true        
  ELSE                                                              
    RETURN false

PRI get (nameAddr, size, type) | v[2], dataAddr
'' return numerical value

  IF (getaddr(nameAddr, @v) <> -1)                                              ' if current name exists
    IF (v.byte[0] <> type)                                                      ' check that type matches
      RETURN false               

    dataAddr := v.word[3]
    CASE type
      TBYTE: RETURN byte[read(dataAddr, 1)]
      TWORD: RETURN word[read(dataAddr, 2)]
      TLONG:
        bytemove(@v, read(dataAddr, 4), 4)
        RETURN v         
  ELSE                                  
    RETURN false  

PRI match_pattern (sourceAddr, patternAddr)
'' ported code from http://vijayinterviewquestions.blogspot.com/2007/07/write-c-program-which-does-wildcard.html
'' seems to work good, but it's recursive, so it could use a significant
'' amount of STACK space depending on the number wild cards there are

  REPEAT WHILE (byte[sourceAddr])                                               ' go through entire string
    CASE byte[patternAddr]                                                      ' check for wild card character
      "*":
        REPEAT
          patternAddr++                                                         ' do this at least once, repeat until no more wild card characters
        WHILE byte[patternAddr] == "*"

        IF NOT(byte[patternAddr])                                               ' return true if end of string is reached
          RETURN true

        REPEAT WHILE byte[sourceAddr]
          IF (match_pattern(sourceAddr++, patternAddr))                         ' recurse!
            RETURN true
        RETURN false

      OTHER:
        IF byte[sourceAddr] <> byte[patternAddr]                                ' check for a match
          RETURN false   

    patternAddr++
    sourceAddr++

  REPEAT WHILE (byte[patternAddr] == "*")                                       ' skip repetitive wild card characters
    patternAddr++
  RETURN NOT(byte[patternAddr]) 

PRI setaddr (nameAddr) | v, ptr, ptr2
'' return address for a new entry
                            
  name_truncate(nameAddr)

  ptr2 := ptr := gethash(nameAddr) 
  
  REPEAT UNTIL (ptr + 2 == ptr2)
    v := table[ptr]

    IF (v == 0)
      RETURN ptr

    IF (strcomp(read(v[0] >> 16, v.byte[1]), nameAddr))
      RETURN -1                                   

    IF ((ptr += 2) => table_size)
      ptr := 0 
  
  RETURN -1

PRI getaddr (nameAddr, tblAddr) | v[2], ptr, ptr2
'' return address for an existing entry

  name_truncate(nameAddr)

  ptr2 := ptr := gethash(nameAddr) 

  REPEAT UNTIL (ptr + 2 == ptr2)
    longmove(@v, @table[ptr], 2)

    IF (v[0] == 0)
      QUIT

    IF (strcomp(read(v[0] >> 16, v.byte[1]), nameAddr))  
      bytemove(tblAddr, @v, 8)
      RETURN ptr                                   
    
    IF ((ptr += 2) => table_size)
      ptr := 0
  
  bytefill(tblAddr, 0, 8)
  RETURN -1

PRI gethash (nameAddr) : hash 
' return a simple checksum within the confines of table_size                  

  hash := $55555555                                                             ' alternating 1s and 0s
  REPEAT strsize(nameAddr)
    hash += byte[nameAddr++] + hash << 5

  hash := (||hash // constant(table_size / 2)) << 1                             ' even numbers 0 through table_size

PRI tsort (ptr) | ptr2, sptr, table_ptr, name[name_size]
'' Move table entries to appropriate location after a rename
'' This is necesary for when entries have collided.

  ptr2 := ptr
  IF ((ptr += 2) => table_size)
    ptr := 0

  REPEAT WHILE (((sptr := table[ptr]) <> 0) AND (ptr <> ptr2))
    bytemove(@name, read(sptr >> 16, name_size), name_size)

    IF ((table_ptr := setaddr(@name)) <> -1)                                    ' get new name location
      IF (ptr <> table_ptr)        
        longmove(@table[table_ptr], @table[ptr], 2)
        write(table_ptr << 2 + start_table, @table[table_ptr], 8)
        longfill(@table[ptr], 0, 2)
        write(ptr << 2 + start_table, @table[ptr], 8) 

    IF ((ptr += 2) => table_size)
      ptr := 0

PRI shellsort1 (arrayAddr, arraylength) | inc, tmp, tmp2[name_size / 4], i, j
'' Sorts array of addresses to strings based on string tmpue
'' faster than insertion sort (for larger arrays)

  inc := arraylength-- >> 1                                                     ' get middle point (reduce arraylength so it's not re-evaluated each loop)
  REPEAT WHILE (inc > 0)                                                        ' while still things to sort
    REPEAT i FROM inc TO arraylength
      tmp := long[arrayAddr][i]                                                 ' store tmpue for later
      bytemove(@tmp2, read(tmp >> 16, tmp.byte[1]), tmp.byte[1])                ' move to location so a second read can be performed
      j := i
      REPEAT WHILE (j => inc) 
        IF (strcmp1(long[arrayAddr][j - inc] >> 16, @tmp2) > 0) 
          long[arrayAddr][j] := long[arrayAddr][j - inc]                        ' insert value
          j -= inc                                                              ' increment
        ELSE
          QUIT 
      long[arrayAddr][j] := tmp                                                 ' place tmpue (from earlier) 
    inc >>= 1                                                                   ' divide by 2. optimal would be 2.2 (due to geometric stuff)

PRI insertionsort1 (arrayAddr, arraylength) | j, i, tmp, tmp2[name_size / 4]
'' Sorts array of address to strings based on string value
'' using the insertion sort method ported from the relevant Wikipedia page

  arraylength--                                                                 ' reduce this so it doesn't re-evaluate each loop
  REPEAT i FROM 1 TO arraylength 
    tmp := long[arrayAddr][i]                                                   ' get replacement value for later
    bytemove(@tmp2, read(tmp >> 16, tmp.byte[1]), tmp.byte[1])                  ' move to location so a second read can be performed
    j := i - 1

    REPEAT WHILE (strcmp1(long[arrayAddr][j] >> 16, @tmp2) > 0)                 ' compare strings
      long[arrayAddr][j + 1] :=  long[arrayAddr][j]                             ' move values
       
      IF (--j < 0)
        QUIT

    long[arrayAddr][j + 1] := tmp                                               ' move values

PRI strcmp1 (s1, s2) | tmp
'' thanks Jon "JonnyMac" McPhalen (aka Jon Williams) (jon@jonmcphalen.com) for the idea/example that alled me to write this code
'' altered so results are not case sensitive, and slightly faster (when considering the case insensitivity)
'' to speed things up (be less dependant on EEPROM read speed) s2 is read before strcmp is called and passed as local address
''   while s1 is passed as an EEPROM location. This allows for significantly less bytes to be read from EEPROM.
'' s1 is an EEPROM location, s2 is a local address. This hybrid compare speeds up the sorting methods. 

'' Returns 0 if strings equal, positive if s1 > s2, negative if s1 < s2

  REPEAT WHILE (((tmp := byte[read(s1, 1)]) & constant(!$20)) == (byte[s2] & constant(!$20))) ' if equal (not perfect case insensitivity, but fast -- we mostly work with just a-z/0-9)
    IF (tmp == 0 OR byte[s2] == 0)                                              '  if at end
      RETURN 0                                                                  '    done
    ELSE
      s1++                                                                      ' advance pointers
      s2++

  RETURN ((tmp & constant(!$20)) - (byte[s2] & constant(!$20)))

PRI storage_fault (ptrval, size)
'' detect if the value will be stored accross a page fault, return corrected value

  IF (ptrval // page_size > (ptrval + size - 1) // page_size)                   ' simple math to see if data is going to span across a sector
    RETURN ptrval + page_size - ptrval // page_size                             ' put data pointer onto next multiple of page_size
  ELSE
    RETURN ptrval

PRI name_truncate (nameAddr) : name_str_size
'' truncates string of a maximum size, maintains same address

  name_str_size := strsize(nameAddr) + 1
  IF (name_str_size > name_size)                                                ' if new name is too large, make a shortened version
    byte[nameAddr + (name_str_size := name_size) - 1] := 0      

DAT
{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}