# Class descriptions

## modControl

Controls processing.

- G

## modProgram

Singleton responsible for interaction with the program table.

### Attributes

| Attribute    | Description                                                  |
| ------------ | ------------------------------------------------------------ |
| id           | Primary key of active program                                |
| name         | Name of active program                                       |
| program_list | All available programs                                       |
| dirty        | Set to 1 if a new record has been created and/or program_list might be out-of-date. |



### Methods

### set

If dirty is 1, then call fetch_programs

Select a program from a list of all programs, or optionally creating a new one. If a new one is created, then a new record is created and dirty is set to 1.

Both 'name' and 'id' are set on exit.

### fetch_programs

Populate program_list with all programs and primary key (id). Dirty is set to 0;

 

## modSeries

Singleton responsible for interaction with the program table.

### Attributes

| Attribute | Description                   |
| --------- | ----------------------------- |
| id        | Primary key of active program |
| val       | Number of active series       |



### Methods

### set

If dirty is 1, then call fetch_programs

Select a program from a list of all programs, or optionally creating a new one. If a new one is created, then a new record is created and dirty is set to 1.

Both 'name' and 'id' are set on exit.

### fetch_programs

Populate program_list with all programs and primary key (id). Dirty is set to 0;