#### AUTOLIMR ####
## © Author: Ben Brooker ####

#### Load required packages from library ####

library(stringr)
library(dplyr, warn.conflicts = F)
library(openxlsx)
library(glue)
library(reshape)
library(tidyr, warn.conflicts = F)

## The below objects are defined to run the function code section by section. To test, run the function code only, 
# then call the function and define the objects in the function call (see below the function definition)


# set working directory
# setwd()



#### VARIABLE DEFINITION FOR TESTING - ONLY USE WHEN TESTING THE FUNCTION ####

# #pathwd <- "D:/Documents/PhD/Thesis/Chapters/Network construction and diagnostics_3/Example networks/4node_test 13 Jan 2022/Stable/"
# Fmats_wbk <- "4node_Fmats.xlsx"#"F_matrices_MDNets_GG.xlsx"
# biom_ineq_wbk <- "4node_bioms_ineqs.xlsx"#"Biomass and inequalities_MDNets_GG.xlsx"
# compartment_col = "Compartment name"#1#2
# fromto <- "Q"
# compartment_sheet <- 1#NULL
# authorname <- "Ben Brooker"
# resp_element = "CO2"
# QPRUA = c("Q","P","R","Unused_energy")
# prim_prod <- "Plant"#c("phyto","mpb")
# ratio_col_ineqs <- 2
# living <- "Alive?"
# unweighted = TRUE
# custom_wbk = "4node_custom_declarations.xlsx"#"custom_lims.xlsx"





#### START DEFINING FUNCTION ####
autoLIMR <- function(pathwd = NULL, 
                     Fmats_wbk = NULL, 
                     biom_ineq_wbk = NULL,
                     compartment_col = NULL, 
                     fromto = "Q", 
                     compartment_sheet = NULL,
                     authorname = "User",
                     QPRUA = NULL, 
                     resp_element="CO2", 
                     prim_prod = NULL, 
                     ratio_col_ineqs = NULL, 
                     living = NULL, 
                     unweighted = FALSE,
                     custom_wbk = NULL) {
  
  #### BASIC READING IN ####
  
  respie_element <- tolower(resp_element)
  if(respie_element == "none") {resp_element <- respie_element}
  
  
  ## Print errors for missing inputs
  if(is.null(biom_ineq_wbk)) {stop("Please provide the name of the workbook containing biomass and inequalities ('biom_ineq_wbk' argument).")}
  options(warn = 1)
  if(is.null(Fmats_wbk)) {stop("Please provide the name of the workbook containing F-matrices ('Fmats_wbk' argument).")}
  
  ## Print warnings for missing inputs
  if(is.null(compartment_sheet)) {message("'compartment_sheet' argument empty, defaulting to sheet 1.")
    compartment_sheet <- 1}
  if(is.null(compartment_col)) {message("'compartment_col' argument empty, defaulting to column 1.")
    compartment_col <- 1}
  
  if(is.null(living)) {message("'living' argument empty, defaulting to column 2.")
    living <- 2}
  
  if(is.null(ratio_col_ineqs)) {message("'ratio_col_ineqs' argument empty, defaulting to column 2.")
    ratio_col_ineqs <- 2}
  if(!is.null(ratio_col_ineqs) && !is.numeric(ratio_col_ineqs)) {ratio_col_ineqs <- gsub(" ","_",ratio_col_ineqs)} # remove spaces 
  
  if(!is.null(pathwd)) {setwd(pathwd)}  
  
  
  #setwd(pathwd)
  options(scipen = 999) # disable scientific notation in R so you don't print e and lim messes up
  options(dplyr.summarise.inform = F)
  
  Fnames <- openxlsx::getSheetNames(Fmats_wbk)
  netFs <- lapply(Fnames,openxlsx::read.xlsx,xlsxFile=Fmats_wbk) # read in each sheet
  Fnames <- gsub(" ","_",Fnames)
  names(netFs) <- Fnames
  
  
  ## make first col rownames and remove first col from each network F matrix
  netFs<-lapply(netFs, function(x) {rownames(x) <- x[,1]
  x <- x[,-1];x}) ## Works
  biomass <-read.xlsx(biom_ineq_wbk, sheet = compartment_sheet)
  colnames(biomass) <- gsub(".","_",colnames(biomass), fixed = T) # remove spaces/fullstops
  Biom_names <- openxlsx::getSheetNames(biom_ineq_wbk)
  ineq_list <- lapply(Biom_names,openxlsx::read.xlsx,xlsxFile=biom_ineq_wbk) # read in each sheet
  Biom_names <- gsub(" ", "_", Biom_names) # remove spaces/fullstops
  names(ineq_list) <- Biom_names
  for (i in seq_along(ineq_list)) {colnames(ineq_list[[i]]) <- gsub(".","_",colnames(ineq_list[[i]]), fixed = T)} # remove spaces/fullstops
  
  ## In case the user had their multiple networks in different orders in the columns of the bioms_ineq_wbk
  ## and the sheets of the Fmats_wbk
  
  if(!is.numeric(compartment_sheet)) {compartment_sheet <- which(Biom_names == compartment_sheet)}
  ineq_list <- ineq_list[-compartment_sheet]
  
  for(j in seq_along(ineq_list)) {
    net_inds <- netFs
    for(i in seq_along(net_inds)) {
      net_inds[[i]] <- grep(Fnames[i],colnames(ineq_list[[j]]))
    }
    
    meta_data <- ineq_list[[j]][-as.vector(unlist(net_inds))]
    ineq_info <- ineq_list[[j]][as.vector(unlist(net_inds))]
    
    
    ineq_list[[j]] <- bind_cols(meta_data,ineq_info)
  }
  ##
  
  dir.create("autoLIMR outputs")
  #path <- paste0(pathwd,"/autoLIMR outputs")
  work_dir <- getwd()
  path <- paste0(getwd(),"/autoLIMR outputs")
  setwd(path)
  
  #### COMPARTMENTS ####
  ## isolate and remove biomass from the list of Fmatrices
  
  #biom.ind <- grep('biomass|inequalities|ratios', names(netFs), ignore.case = T) ## get biomass index, as long as the file has the word 'biomass' in it
  
  if (!is.numeric(compartment_col)) {compartment_col <- gsub(" ","_",compartment_col)}
  if (is.numeric(compartment_col)) { comp_names <- colnames(biomass)[compartment_col]}else {comp_names <- compartment_col
  } 
  
  
  if (!is.numeric(ratio_col_ineqs)) {ratio_col_ineqs <- gub(" ","_", ratio_col_ineqs)}
  #if(is.numeric(int_ext_col)) {int_ext_col_ind <- int_ext_col
  #  int_ext_col <- colnames(biomass)[int_ext_col]}
  #if(!is.numeric(int_ext_col)) {int_ext_col_ind <- which(colnames(biomass) == int_ext_col)}
  
  #if(is.numeric(biomass[,int_ext_col_ind])) {biomass[,int_ext_col_ind] <- gsub(1,"INTERNAL",biomass[,int_ext_col_ind])
  #biomass[,int_ext_col_ind] <- gsub(0,"EXTERNAL",biomass[,int_ext_col_ind])}
  #if(!is.numeric(biomass[,int_ext_col_ind])) {biomass[,int_ext_col_ind] <- toupper(biomass[,int_ext_col_ind])}
  
  if(is.numeric(living)) {living_ind <- living
  living <- colnames(biomass)[living]}
  if(!is.numeric(living)) {
    living <- gsub(" ","_",living)
    living_ind <- which(colnames(biomass) == living)}
  
  if(is.numeric(biomass[,living_ind])) {biomass[,living_ind] <- gsub(1,"LIVING",biomass[,living_ind])
  biomass[,living_ind] <- gsub(0,"NON-LIVING",biomass[,living_ind])}
  biomass[,living_ind] <- toupper(biomass[,living_ind])
  
  ## Identify non-living nodes and isolate the compartment names
  ## paste NLNode onto the names for replacement
  
  #NLs <- biomass[which(biomass[,int_ext_col_ind] == "INTERNAL",),]
  NLcomps <- biomass[,compartment_col][which(biomass[,living_ind] != "LIVING")]
  # check with NLcomps if they have NLNode or not
  NLcomps_edit <- NULL
  for(i in seq_along(NLcomps)) {
    if (length(grep("NLNode", NLcomps[i], ignore.case = T)) == 0) {
      NLcomps_edit <- c(NLcomps_edit,NLcomps[i])
    }
  }
  # if there are non-living nodes without NLNode - add it to them in a replacement object
  # to be used later
  if(!is.null(NLcomps_edit)) {
    NLrepl <- paste0(NLcomps,"NLNode")  
  }
  
  #NLcomps[-which(duplicated(NLcomps))]
  #which(duplicated(NLrepl))
  #which(duplicate(NLcomps_edit))
  
  
  # isolate internal biomasses
  internal_bioms <- biomass%>% # isolate internal biomass only - no comp abbrevs
    #filter(get(int_ext_col) %in% "INTERNAL") %>%
    select(c(all_of(comp_names),paste(Fnames, sep = "|")))
  
  internal_bioms[,-1] <- apply(apply(internal_bioms[,-1],2,function(x){gsub(",",".",x)}),2,as.numeric)
  
  # sum up values of any with the same name (if people have gathered data from different time periods or something they may have
  # the same compartment twice)
  internal_bioms <- internal_bioms%>%
    group_by_at(comp_names) %>%
    summarise(across(where(is.numeric), ~ sum(.x, na.rm = TRUE)))## OR operator (|) allows for selecting according to a string vector
  
  # isolate the abbreviations/comp names for use in LIMfile
  internal_abbrevs <- internal_bioms %>%
    select(all_of(comp_names))
  
  # isolate the biomass values
  internal_bioms <- internal_bioms %>% # isolate comp abbrevs for just the internal bioms
    select(!all_of(comp_names))
  
  internal_bioms <- as.data.frame(internal_bioms) # get back to regular data frame to mitigate tibble errors
  internal_abbrevs <- as.data.frame(internal_abbrevs)
  
  # paste NLNode onto the internal NL comps if needed
  if(!is.null(NLcomps_edit)) {
    internal_abbrevs[,1] <- Reduce(function(x, i) gsub(paste0("\\b", NLcomps_edit[i], "\\b"), NLrepl[i], x), 
                                   seq_along(NLcomps_edit),  internal_abbrevs[,1])  
  }
  
  # make the list with all comps and their values for each time step
  internal_bioms_list <- vector(mode = 'list', length = (length(Fnames)))# list for bioms
  names(internal_bioms_list) <- Fnames
  
  for (i in 1:ncol(internal_bioms)) { # excluding the comp abbrev
    for (j in 1:nrow(internal_bioms)) {
      if (internal_bioms[j,i] == 0||is.na(internal_bioms[j,i])) {next}
      
      x <- paste(internal_abbrevs[,1][j],"=", internal_bioms[j,i])
      internal_bioms_list[[i]] <- c(internal_bioms_list[[i]], x)
    }
  }
  
  ## this puts the NLNodes at the end of the compartments as required by flowcar
  for(i in 1:length(internal_bioms_list)) {
    x<-internal_bioms_list[[i]]
    NLNode_ind <- grep("NLNode", x, ignore.case = T)
    NLNodes <- x[NLNode_ind]
    x<-x[-NLNode_ind]
    x <- c(x,NLNodes)
    internal_bioms_list[[i]] <- x  
  }
  
  message("Internal compartments done")
  
  #### EXTERNALS ####
  externals_list <- netFs
  
  for(j in seq_along(externals_list)) {
    cols <- colnames(netFs[[j]])
    rows <- rownames(netFs[[j]])
    
    if(!identical(cols,rows)) {
      a<-setdiff(cols,rows)
      b<-setdiff(rows, cols)
      if(length(a) > 0) {warning(paste0("Adjacency matrix rows and columns not identical for ",names(netFs)[j],
                                        ". Compartments missing in rows: ",paste0(a, collapse = ", ")))}
      
      if(length(b) > 0) {warning(paste0("Adjacency matrix rows and columns not identical for ",names(netFs)[j],
                                        ". Compartments missing in columns: ",paste0(b, collapse = ", ")))}
    }
    
    ext_cols <- grep(paste0(c(if(resp_element != "none"){resp_element},"Export","Input"), collapse = "|"), cols, ignore.case = T, value = T)
    ext_rows <- grep(paste0(c(if(resp_element != "none"){resp_element},"Export","Input"), collapse = "|"), rows, ignore.case = T, value = T)
    
    if(!identical(ext_cols, ext_rows)) {
      if(length(ext_cols) > length(ext_rows)) {exts <- ext_cols}
      if(length(ext_rows) > length(ext_cols)) {exts <- ext_rows}
    } else {exts <- ext_rows}
    
    
    # AUTOMATICALLY PUT NLNODE IN BETWEEN INPUTS AND EXPORTS
    
    if(!is.null(NLcomps_edit)) {
      
      exts <- gsub("Import","Input",exts)
      exts <- gsub("Input","_Input",exts)
      exts <- gsub("Export","_Export",exts)
      y <- lapply(strsplit(exts, "_"), as.data.frame)
      y <- lapply(y,t)
      y <- lapply(y, as.data.frame)
      y <- bind_rows(y)
      rownames(y) <- NULL
      y[,1] <- Reduce(function(x, i) gsub(paste0("\\b", NLcomps_edit[i], "\\b"), NLrepl[i], x), 
                      seq_along(NLcomps_edit),  y[,1])
      y <- paste0(y[,1],y[,2])
      y <- gsub("NA","",y)  
      exts <- y
      
    }
    externals_list[[j]] <- exts
  }
  
  ## Check that the new method returns identical externals list to the original way
  #for(k in seq_along(externals_list)) {
  #  print(identical(externals_list[[k]][order(externals_list[[k]])],orig[[k]][order(orig[[k]])]) ) 
  #}
  ## it does
  
  ##--
  
  ## This puts the respiration element first as is required by flowcar
  if(resp_element != "none") {
    for(i in 1:length(externals_list)) {
      x <- externals_list[[i]]
      y<-x[grep(resp_element,x)]
      x<-x[-grep(resp_element,x)]
      z <- c(y,x)
      externals_list[[i]] <-z
    }  
  }
  
  
  ## SEARCH NETFS AND DO THE SAME AS THE INTERNAL COMPS
  # search colnames -> split into internal comps and external comps ->  search comps and add NLNode to NLcomps ->
  # paste them back together again -> replace original colnames.
  # Repeat for rownames.
  
  # search colnames -> split into comps and input/exports df -> paste NLcomps w NLNode in 1st column of df and stick together
  if(!is.null(NLcomps_edit)) {
    for(i in seq_along(netFs)) {
      p <- colnames(netFs[[i]])
      p <- gsub("Import","Input",p)
      p <- gsub("Input","_Input",p)
      p <- gsub("Export","_Export",p)
      
      y <- lapply(strsplit(p, "_"), as.data.frame)
      y <- lapply(y,t)
      y <- lapply(y, as.data.frame)
      y <- bind_rows(y)
      rownames(y) <- NULL
      
      y[,1] <- Reduce(function(x, i) gsub(paste0("\\b", NLcomps_edit[i], "\\b"), NLrepl[i], x), 
                      seq_along(NLcomps_edit),  y[,1])
      y <- paste0(y[,1],y[,2])
      y <- gsub("NA","",y)  
      p <- y
      colnames(netFs[[i]]) <- p
    }
    
    # search rownames -> split into comps and input/exports df -> paste NLcomps w NLNode in 1st column of df and stick together
    for(i in seq_along(netFs)) {
      p <- rownames(netFs[[i]])
      p <- gsub("Import","Input",p)
      p <- gsub("Input","_Input",p)
      p <- gsub("Export","_Export",p)
      
      y <- lapply(strsplit(p, "_"), as.data.frame)
      y <- lapply(y,t)
      y <- lapply(y, as.data.frame)
      y <- bind_rows(y)
      rownames(y) <- NULL
      
      y[,1] <- Reduce(function(x, i) gsub(paste0("\\b", NLcomps_edit[i], "\\b"), NLrepl[i], x), 
                      seq_along(NLcomps_edit),  y[,1])
      y <- paste0(y[,1],y[,2])
      y <- gsub("NA","",y)  
      p <- y
      rownames(netFs[[i]]) <- p
    }
  }
  
  
  # Warnings - identify discrepancies between biomass sheet compartments and compartments in F matrices for the same netowrks/time steps
  # Tells the user what the problem compartments are
  
  for(i in 1:length(netFs)) {
    colcomps <- grep(paste0(c("Export", "Input", "NLNode", if(resp_element != "none"){resp_element}),collapse="|"), colnames(netFs[[i]]), ignore.case=T,value=T,invert=T)
    rowcomps <- grep(paste0(c("Export", "Input", "NLNode", if(resp_element != "none"){resp_element}),collapse="|"), rownames(netFs[[i]]), ignore.case=T,value=T,invert=T)
    comps <- grep("NLNode",paste0(data.frame(strsplit(internal_bioms_list[[i]],split = " = "))[1,]),invert=T,value=T,ignore.case = T)
    colcomps <- colcomps[order(colcomps)]
    rowcomps <- rowcomps[order(rowcomps)]
    if(!identical(rowcomps,comps)) {
      
      a<-setdiff(rowcomps,comps)
      b<-setdiff(comps, rowcomps)
      if(length(a) > 0) {warning(paste0("Adjacency matrix internal compartments in rows and internal compartments in biomass sheet not identical for ",names(netFs)[i],
                                        ". Compartments missing in biomass sheet: ",paste0(a, collapse = ", ")))}
      
      if(length(b) > 0) {warning(paste0("Adjacency matrix internal compartments in rows and internal compartments in biomass sheet not identical for ",names(netFs)[i],
                                        ". Compartments missing in adjacency matrix rows: ",paste0(b, collapse = ", ")))}
    }
    
    if(!identical(colcomps,comps)) {
      
      a<-setdiff(colcomps,comps)
      b<-setdiff(comps, colcomps)
      if(length(a) > 0) {warning(paste0("Adjacency matrix internal compartments in columns and internal compartments in biomass sheet not identical for ",names(netFs)[i],
                                        ". Compartments missing in biomass sheet: ",paste0(a, collapse = ", ")))}
      
      if(length(b) > 0) {warning(paste0("Adjacency matrix internal compartments in columns and internal compartments in biomass sheet not identical for ",names(netFs)[i],
                                        ". Compartments missing in adjacency matrix columns: ",paste0(b, collapse = ", ")))}
      
    }
  }
  
  
  #### WRITE INTERNALS AND EXTERNALS
  
  dir.create("Biomass")
  wd<- paste0(path,"/Biomass")
  setwd(wd)
  ## for each df in netbiom list - write that df to txt file named the same as that df - saved to same wd() as read in
  for (i in 1:length(internal_bioms_list)) {
    writeLines(internal_bioms_list[[i]],paste0(names(internal_bioms[i])," biomass",".txt"))
  }
  
  setwd(path)
  dir.create("Externals")
  wd<- paste0(path,"/Externals")
  setwd(wd)
  
  for (i in 1:length(externals_list)) {
    writeLines(externals_list[[i]],paste0(names(externals_list[i])," externals",".txt"))
  }
  
  message("External compartments done")
  
  setwd(path)
  
  #### QPRUA DEFINITION ####
  
  if(is.null(QPRUA)) {
    
    Biom_names <- gsub("_"," ",Biom_names)
    
    cons <- grep("\\bconsumption\\b|\\bcons\\b|\\bc\\b|\\bingestion\\b|\\bing\\b|\\bi\\b|\\bq\\b|\\bingest\\bconsumpt\\b|\\bconsump\\b|\\bconsum\\b|\\bgpp\\b",Biom_names, ignore.case = T, value = T)
    cons <- gsub(" ","_", cons)
    
    prod <- grep("\\bproduction\\b|\\bprod\\b|\\bp\\b|\\bproduct\\b|\\bproductivity\\b|\\bnpp\\b",
                 Biom_names, ignore.case = T, value = T)
    prod <- gsub(" ","_", prod)
    
    if(resp_element != "none") {resp <- grep("\\brespiration\\b|\\bresp\\b|\\br\\b|\\brespire\\b|\\bbmr\\b|\\bbasal metabolic rate\\b|\\bbase met rate\\b|\\bbasal metab rate\\b",
                                             Biom_names, ignore.case = T, value = T)
    resp <- gsub(" ","_",resp)}
    
    
    unused <- grep("\\begestion\\b|\\begest\\b|\\be\\b|\\bexcretion\\b|\\bexcrete\\b|\\bpoo\\b|\\bdefecation\\b|\\bdefecate\\b|\\bdefaecate\\b|\\bdefaecation\\b|\\bfeces\\b|\\bfaeces\\b
                   |\\bunused\\b|\\bu\\b|\\bunidentified\\b|\\buseless\\b|\\bunused\\b|\\bun\\b|\\bunu\\b|\\unused_energy\\b",
                   Biom_names, ignore.case = T, value = T)
    unused <- gsub(" ","_",unused)
    
    if(resp_element != "none") {assim <- grep("\\bassimilation_efficiency\\b|\\basseff\\b|\\bA\\b|\\bAE\\b|\\bassimeff\\b|\\bassim_eff\\b|\\bass_effic\\b|\\basseffic\\b|\\bass\\b|\\bassim\\b|\\bassimilation_efficiencies\\b|\\bassimilation\\b",
                                              Biom_names, ignore.case = T, value = T)
    assim <- gsub(" ","_",assim)}
    
    Biom_names <- gsub(" ","_",Biom_names)
    
  } else if (resp_element != "none") {
    
    QPRUA <- gsub(" ", "_", QPRUA)
    
    cons = QPRUA[1]
    prod = QPRUA[2]
    resp = QPRUA[3]
    unused = QPRUA[4]
    assim = QPRUA[5]
    
  } else {
    
    QPRUA <- gsub(" ", "_", QPRUA)
    
    cons = QPRUA[1]
    prod = QPRUA[2]
    unused = QPRUA[3]
    
  }
  
  if (resp_element != "none") {
    if (is.na(assim) || length(assim) == 0) {
      if(!is.null(QPRUA)) {QPRUA <- c(QPRUA, "AE")}
      assim <- "AE"
    }
  }
  
  # Message for User checks
  # No QPRUA with resp
  if(is.null(QPRUA) && resp_element != "none") {message(paste0("No input for QPRUA argument, variable names assigned from inequality sheets : \n
                              Q : ",cons,"\n
                              P : ",prod,"\n
                              R : ",resp,"\n
                              U : ",unused,"\n
                              A : ",assim))}
  # No QPRUA w/out resp
  if(is.null(QPRUA) && resp_element == "none") {message(paste0("No input for QPRUA argument, variable names assigned from inequality sheets: \n
                              Q : ",cons,"\n
                              P : ",prod,"\n
                              R : No respiration element\n
                              U : ",unused,"\n
                              A : N/A"))}
  # QPRUA with resp
  if(!is.null(QPRUA) && resp_element != "none") {message(paste0("Variable names assigned according to QPRUA argument : \n
                              Q : ",cons,"\n
                              P : ",prod,"\n
                              R : ",resp,"\n
                              U : ",unused,"\n
                              A : ",assim))}
  
  if(!is.null(QPRUA) && resp_element == "none") {message(paste0("Variable names assigned according to QPRUA argument : \n
                              Q : ",cons,"\n
                              P : ",prod,"\n
                              R : No respiration element\n
                              U : ",unused,"\n
                              A : N/A"))}
  
  #### FLOWS #####
  
  netflows <- vector("list", length = length(Fnames))
  names(netflows) <- Fnames
  
  Fmat_ineqs <- netflows
  
  
  for (k in 1:length(netFs)) {
    for (i in 1:nrow(netFs[[k]])) { # loop across rows and cols of individual F matrices
      for (j in 1:ncol(netFs[[k]])) {
        
        # The following separates out each flow in the network flow matrix and assigns it a name:
        # EX/IN for Export and Input respectively, 
        #Egestion/Mortality for each of those, 
        #Q (or whatever fromto is) for diet flows
        
        if (!is.na(netFs[[k]][i,j]) && !netFs[[k]][i,j] == 0){ # only do the following where there is not an NA and the value is NOT zero
          z <- NULL
          z2 <- NULL
          to <- colnames(netFs[[k]])[j]
          from <- rownames(netFs[[k]])[i]
          if (to == resp_element) {z = paste0(from,resp,": ", from, " -> ", to, collapse=' ')}
          else if (length(grep("Export",to, ignore.case = T, value = T)) != 0) {z= paste0(from, "EX",": ", from, " -> ", to, collapse=' ')}
          else if (length(grep("Input",from, ignore.case = T, value = T)) != 0) {z= paste0(to, "IN",": ", from, " -> ", to, collapse=' ')}
          else if (length(grep("NLNode",to, ignore.case = T,value = T)) != 0 && length(grep("NLNode",from, ignore.case = T, value = T, invert = T)) != 0) 
          {z= paste0(from, unused,": ", from, " -> ", to, collapse=' ')
          }
          else {z <- paste0(to, fromto, from, ": ", from, " -> ", to, collapse=' ')}
          
          for (t in 1:length(netflows)) {
            if (names(netFs[k]) == names(netflows[t])) {
              netflows[[t]] <- c(netflows[[t]], z) ## sequentially feed in each flow as it is defined above
            }
          }
        }
        
        # End flow definition and naming
        
        
        ## The following defines the inequality for the given diet flow
        # Upper limit
        # Lower limit
        # Equalities
        # Lower and Upper limit
        
        x<-unlist(strsplit(as.character(netFs[[k]][i,j]),","))
        if(!is.na(x) && length(x) == 1 && !as.numeric(x) == 1) { ## when there is a single value 
          flow <- strsplit(z,": ")[[1]][1]           ## and that value is not 1, this is the upper limit only
          eating_comp <- strsplit(flow,fromto)[[1]][1]
          if(length(grep("IN\\b",flow,ignore.case = F)) == 1 || length(grep("EX\\b", flow, ignore.case = F)) ==1){
            ineq <- paste0(flow," < ",x[1])
          } else {ineq <- paste0(flow," < ",x[1],"*",eating_comp,cons)}
          Fmat_ineqs[[k]] <- c(Fmat_ineqs[[k]],ineq)
        } else if (!is.na(x) && length(x) == 2 && x[2] == 1) { ## when there are two values and the 2nd is 1
          flow <- strsplit(z,": ")[[1]][1]           ## it indicates a lower limit only to the flow
          eating_comp <- strsplit(flow,fromto)[[1]][1]
          if(length(grep("IN\\b",flow,ignore.case = F)) == 1 || length(grep("EX\\b", flow, ignore.case = F)) ==1){
            ineq <- paste0(flow," > ",x[1])
          } else {ineq <- paste0(flow," > ",x[1],"*",eating_comp,cons)}
          Fmat_ineqs[[k]] <- c(Fmat_ineqs[[k]],ineq)
        } else if (!is.na(x) && length(x) == 2 && x[1] == x[2]) { ## this is if it is an equality
          flow <- strsplit(z,": ")[[1]][1]                         ## both indices for x are the same
          eating_comp <- strsplit(flow,fromto)[[1]][1]
          if(length(grep("IN\\b",flow,ignore.case = F)) == 1 || length(grep("EX\\b", flow, ignore.case = F)) ==1){
            ineq_up <- paste0(flow," < ",x[2])
            ineq_low <- paste0(flow," > ",x[1])
          } else {ineq_up <- paste0(flow," < ",x[2],"*",eating_comp,cons)
          ineq_low <- paste0(flow," > ",x[1],"*",eating_comp,cons)}
          Fmat_ineqs[[k]] <- c(Fmat_ineqs[[k]],ineq_up,ineq_low)
        } else if (!is.na(x) && length(x) == 2 && !x[1] == x[2]) { ## this is for an upper AND lower limit
          flow <- strsplit(z,": ")[[1]][1]                         ## indices for x are different
          eating_comp <- strsplit(flow,fromto)[[1]][1]
          if(length(grep("IN\\b",flow,ignore.case = F)) == 1 || length(grep("EX\\b", flow, ignore.case = F)) ==1){
            ineq_up <- paste0(flow," < ",x[2])
            ineq_low <- paste0(flow," > ",x[1])
          } else {ineq_up <- paste0(flow," < ",x[2],"*",eating_comp,cons)
          ineq_low <- paste0(flow," > ",x[1],"*",eating_comp,cons)}
          Fmat_ineqs[[k]] <- c(Fmat_ineqs[[k]],ineq_up,ineq_low)
        }
      }
    }
  } ## this creates the specific flows, flownames and the flow inequalities into netflows and Fmat_ineqs
  
  
  ### SPLITTING ALL THE FLOWS INTO Exports, Inputs, Diets, Respiration, Unused energy (egestion)
  for(i in 1:length(netflows)) {
    comps <- paste0(data.frame(strsplit(internal_bioms_list[[i]],split = " = "))[1,])
    
    Exs_ind <- grep("EX",netflows[[i]])
    Exs <- netflows[[i]][grep("EX",netflows[[i]])]
    Exs <- Exs[order(Exs)]
    
    Ins_ind <- grep("IN",netflows[[i]])
    Ins <- netflows[[i]][grep("IN",netflows[[i]])]
    Ins <- Ins[order(Ins)]
    
    breathes_ind <- grep(paste(c("-> ",resp_element),collapse=""),netflows[[i]])
    breathes <- netflows[[i]][grep(paste(c("-> ",resp_element),collapse=""),netflows[[i]])]
    breathes <- breathes[order(breathes)]
    
    to_match <- paste0(data.frame(strsplit(netflows[[i]],split = ": "))[1,]) ## all the flow names
    doubles <- to_match[duplicated(to_match)]                               ## doubles of flow names
    if(length(doubles) > 0) {
      doubles_ind <- grep(paste(doubles,collapse = "|"), netflows[[i]])       ## indices of doubles
      doubles <- grep(paste(doubles,collapse = "|"), netflows[[i]],value = T) ## actual doubles flownames and definitions
      doublesdf <- data.frame(strsplit(doubles,split=": "))                    ## dataframe of the flow names and definitions
      doublesdf <- as.data.frame(t(doublesdf))
      doublesdf <- data.frame(doublesdf, index = doubles_ind)                 ## data frame including the original indices in the netflows object
      colnames(doublesdf) <- c("flowname","flow", "index")
      rownames(doublesdf) <- NULL
      exptolose <- grep("Export", doublesdf$flow)
      if(length(exptolose) > 0) {
        doublesdf <- doublesdf[-exptolose,]                ## remove exports if there are any. 
      }
      to_conc <- paste0(data.frame(strsplit(doublesdf$flow,split = " -> "))[2,]) ## split the flow definition up so the NLNodes can be added to the flowname
      doublesdf <- doublesdf %>% mutate(to_conc = to_conc,
                                        dblflow = str_c(flowname,"_",to_conc),
                                        fulldblflow = str_c(dblflow,": ",flow))
      netflows[[i]][as.vector(doublesdf$index)] <- doublesdf$fulldblflow
    }
    
    ## how the fuck to match this shit
    
    ## take comps from network i that are living, attaches egest name to them. These are complete names of the flows we want to isolate 
    poopies <- paste0(comps,unused)[-grep("NLNode",paste0(comps,unused), ignore.case = T)]
    poops <- grep(paste(poopies,collapse="|"),netflows[[i]],value = T)
    if(length(grep("Export",poops)) > 0){
      poops <- poops[-grep("Export",poops)]} 
    poops <- poops[order(poops)]
    poops_ind <- grep(paste0(poops,collapse="|"),netflows[[i]])
    
    ## this way, safeguards against ambiguous naming of the fromto argument
    inds <- c(Exs_ind,Ins_ind,breathes_ind,poops_ind)
    Qs <- netflows[[i]][-inds]
    Qs <- Qs[order(Qs)]
    
    x <- c("!Imports\n",Ins,
           "\n!Exports\n",Exs,
           "\n",paste0("!",cons), "\n", Qs, 
           if (resp_element != "none") {
             c("\n", paste0("!",resp),"\n", breathes)},
           "\n", paste0("!",unused),"\n", poops)
    
    netflows[[i]] <- x
  } ## this includes E and M going to multiple detrital sources
  
  ## Write flows to file
  
  dir.create("Flows")
  wd<- paste0(path,"/Flows")
  setwd(wd)
  
  for (i in 1:length(netflows)) {
    writeLines(netflows[[i]],paste0(names(netflows[i])," flows",".txt"))
  }
  setwd(path)
  
  message("Flows done")
  
  #### VARIABLES ####
  
  net_vars <- netflows
  
  for(i in 1:length(net_vars)) {
    
    comps <- grep("NLNode",paste0(data.frame(strsplit(internal_bioms_list[[i]],split = " = "))[1,]),invert=T,value=T,ignore.case = T)
    
    # IMPORTS
    # Isolate compartments that get imported, and match them to the list of all compartments - create a group
    # of compartments that need defining with imports and a group of compartments that don't
    Ins <- grep("IN", netflows[[i]], value = T)
    Ins <- grep("NLNode|\n|!",Ins, ignore.case = T, value = T, invert = T)
    
    if(length(Ins) > 0) {
      x <-  lapply(strsplit(Ins, ": "),as.data.frame);x <- lapply(x,t);x <- lapply(x, as.data.frame);    x <- bind_rows(x)
      Ins <- x[,1]
      flow <- x[,2]
      x <- lapply(strsplit(flow," -> "), as.data.frame); x <- lapply(x,t);x <- lapply(x, as.data.frame);    x <- bind_rows(x)
      from <- x[,1]
      to <- x[,2]
      importies <- data.frame(Ins, from, to, flow)
      impcomps <- comps[which(comps == importies$to)] # contains living compartments that have exports
      no_impcomps <- comps[which(comps != importies$to)] # contains living compartments that don't have exports
    } else {no_impcomps <- comps
    impcomps <- NULL}
    
    ### Egestion
    Unused <- netflows[[i]][grep(paste0(comps,unused,collapse = "|"),netflows[[i]])][-1] # this is better than just grepping egest, in case of other ambiguities
    Unused <- grep("Export", Unused,ignore.case = F,value = T, invert = T)
    #var_dupl_E[[i]]
    Udf <- as.data.frame(t(data.frame(strsplit(Unused,":"))))
    colnames(Udf) <- c("flowname","flowdef")
    rownames(Udf) <- NULL
    
    Udf <- Udf %>% separate(flowname, c("from","to"),sep = "_",  remove = F,extra = "drop",fill="right") 
    
    dupl_counts <- Udf %>%
      group_by(from) %>%
      summarise(n = n()) %>% 
      filter(n > 1)
    dupl <- dupl_counts$from
    
    if(length(dupl > 0)) {
      dupldf <- Udf[grep(paste0(dupl,collapse="|"), Udf$from),]
      
      var_U <- dupl
      for(p in 1:length(dupl)) {
        x <- dupldf[grep(dupl[p],dupldf$from),]
        y <- paste0(dupl[p]," = ",paste0(x$flowname,collapse = " + "))
        var_U[p] <- y
      }
    }
    
    U_for_P <- paste0(comps,unused)
    
    
    if(resp_element != "none") {
      Respiration <- netflows[[i]][grep(paste(c("-> ",resp_element),collapse=""),netflows[[i]])]#[-1]
      var_R <- paste(as.vector(data.frame(strsplit(Respiration,":"))[1,]))  
    }
    
    # Compartments with no imports:
    if(length(no_impcomps) > 0) {
      if (is.null(prim_prod)) {
        Consumption_no_imp <- paste0(no_impcomps,cons," = Flowto(",no_impcomps,")")  
      }
      if(!is.null(prim_prod)) {prim_prod_index <- grep(paste0(prim_prod,collapse = "|"),no_impcomps)
      ppz <- paste0(no_impcomps[prim_prod_index],"GPP = Flowto(",no_impcomps[prim_prod_index],")")
      Consumption_no_imp <- paste0(no_impcomps,cons," = Flowto(",no_impcomps,")")  
      Consumption_no_imp[prim_prod_index] <- ppz} ##
      var_C_no_imp <- paste(as.vector(data.frame(strsplit(Consumption_no_imp," = "))[1,]))
    }
    
    # Compartments with imports:
    if(length(Ins) > 0) {
      if (is.null(prim_prod)) {
        Consumption_imp <- paste0(impcomps,cons," = Flowto(",impcomps,") - ", impcomps, "IN")  
      }
      if(!is.null(prim_prod)) {prim_prod_index <- grep(paste0(prim_prod,collapse = "|"),impcomps)
      ppz <- paste0(impcomps[prim_prod_index],"GPP = Flowto(",impcomps[prim_prod_index],") - ", impcomps[prim_prod_index],"IN")
      Consumption_imp <- paste0(impcomps,cons," = Flowto(",impcomps,") - ",impcomps,"IN")  
      Consumption_imp[prim_prod_index] <- ppz} ##
      var_C_imp <- paste(as.vector(data.frame(strsplit(Consumption_imp," = "))[1,]))
    } else {Consumption_imp <- NULL
    var_C_imp <- NULL}
    
    Consumption <- c(Consumption_imp, Consumption_no_imp)
    Consumption <- Consumption[order(Consumption)]
    
    var_C <- c(var_C_imp, var_C_no_imp)
    var_C <- var_C[order(var_C)]
    
    
    var_P <- paste0(comps, prod," = Flowfrom(", comps,") - ", if(resp_element != "none"){paste(var_R ," - ")}, U_for_P)
    if(!is.null(prim_prod)) {prim_prod_index <- grep(paste0(prim_prod,collapse = "|"),comps)
    ppz <- paste0(comps[prim_prod_index],"NPP = Flowfrom(",comps[prim_prod_index],") - ",
                  if(resp_element != "none"){paste(var_R[prim_prod_index]," - ")},U_for_P[prim_prod_index])
    var_P[prim_prod_index] <- ppz}
    
    
    Ps <- paste(data.frame(strsplit(var_P," = "))[1,])
    if(resp_element != "none") {var_AE <- paste0(comps,assim," = ",Ps," + ",var_R)}
    
    if(!exists("var_U")) {var_U <- paste0("!","Is defined in the flows section")}
    
    x <- c(paste0("!",cons),"\n",Consumption,
           "\n",paste0("!",unused),"\n",var_U,
           "\n", paste0("!",prod),"\n", var_P,
           if (resp_element != "none") {
             c("\n", paste0("!",assim),"\n", var_AE)   
           })
    
    net_vars[[i]] <- x
    
  } ## this writes the variables section, including the multiple flows for E and M
  ## and GPP and NPP for primary producers
  
  ## Write Variables to file
  
  dir.create("Variables")
  wd<- paste0(path,"/Variables")
  setwd(wd)
  
  for (i in 1:length(net_vars)) {
    writeLines(net_vars[[i]],paste0(names(net_vars[i])," variables",".txt"))
  }
  setwd(path)
  
  message("Variables done")
  
  #### INEQUALITIES ####
  options(warn= -1)
  ## Caters for compartment_sheet being the name or index of the sheet and removes biomass sheet,
  ## leaving only inequalities
  
  
  ## RECONCILE THE SHEET NAMES TO SPECIFIED QPRUA
  
  if(!is.null(QPRUA)) {
    
    names(ineq_list) <- gsub("_"," ", names(ineq_list))
    
    names(ineq_list)[grep("\\bconsumption\\b|\\bcons\\b|\\bc\\b|\\bingestion\\b|\\bing\\b|\\bi\\b|\\bq\\b|\\bingest\\b|\\bconsumpt\\b|\\bconsump\\b|\\bconsum\\b|\\bgpp\\b",names(ineq_list), ignore.case = T)] <- cons
    
    names(ineq_list)[grep("\\bproduction\\b|\\bprod\\b|\\bp\\b|\\bproduct\\b|\\bproductivity\\b|\\bnpp\\b",
                          names(ineq_list), ignore.case = T)] <- prod
    
    if(resp_element != "none") {names(ineq_list)[grep("\\brespiration\\b|\\bresp\\b|\\br\\b|\\brespire\\b|\\bbmr\\b|\\bbasal metabolic rate\\b|\\bbase met rate\\b|\\bbasal metab rate\\b",
                                                      names(ineq_list), ignore.case = T)] <- resp}
    
    names(ineq_list)[grep("\\begestion\\b|\\begest\\b|\\be\\b|\\bexcretion\\b|\\bexcrete\\b|\\bpoo\\b|\\bdefecation\\b|\\bdefecate\\b|\\bdefaecate\\b|\\bdefaecation\\b|\\bfeces\\b|\\bfaeces\\b
                   |\\bunused\\b|\\bu\\b|\\bunidentified\\b|\\buseless\\b|\\bunused\\b|\\bun\\b|\\bunu\\b|\\unused_energy\\b",
                          names(ineq_list), ignore.case = T)] <- unused
    
    
    if(resp_element != "none") {names(ineq_list)[grep("\\bassimilation_efficiency\\b|\\basseff\\b|\\bA\\b|\\bAE\\b|\\bassimeff\\b|\\bassim_eff\\b|\\bass effic\\b|\\basseffic\\b|\\bass\\b|\\bassim\\b|\\bassimilation_efficiencies\\b|\\bassimilation\\b",
                                                      names(ineq_list), ignore.case = T)] <- assim}
    
    names(ineq_list) <- gsub(" ","_", names(ineq_list))
    
  }
  
  
  QPRUA <- c(cons,prod,if(resp_element != "none") {c(resp)},unused,if(resp_element != "none") {c(assim)})
  ineq_list<-ineq_list[QPRUA]
  
  nulls <- as.vector(which(sapply(ineq_list,is.null)))
  if(length(nulls) >0){ineq_list <- ineq_list[-nulls]}
  
  ## create new inequalities list for reordering the chaos
  new_ineq_list <- vector(mode = "list", length = length(ineq_list))
  names(new_ineq_list) <- names(ineq_list)
  
  ## create empty lists in each object of the new inequalities list
  ## so that timesteps can be separate for the remaining operations
  
  empty_netlist <- vector(mode='list',length = length(Fnames))
  names(empty_netlist) <- Fnames
  
  for (i in 1:length(new_ineq_list)) {
    new_ineq_list[[i]] <- empty_netlist
  }
  
  ## This reorders the inequalities so that the timesteps are alone for each
  ## parameter
  if(is.numeric(ratio_col_ineqs)) {
    ratio_ind <- ratio_col_ineqs
    ratio_col_ineqs <- colnames(ineq_list[[1]])[ratio_col_ineqs]
  }
  
  if(!is.numeric(ratio_col_ineqs)) {
    ratio_ind <- which(colnames(ineq_list[[1]]) == ratio_col_ineqs)
  }
  
  
  for(i in 1:length(new_ineq_list)) {
    for(j in 1:length(new_ineq_list[[i]])) {
      x <- ineq_list[[i]]
      x <-x%>%
        select(c(all_of(comp_names),all_of(ratio_col_ineqs),grep(names(netFs)[j],colnames(x), value = T)))
      #print(colnames(x))
      new_ineq_list[[i]][[j]] <- x
    }
  }
  
  summarised_ineqs <- vector(mode="list", length = length(netFs))
  names(summarised_ineqs) <- names(netFs)
  
  empty_varlist <- vector(mode='list',length = length(ineq_list))
  names(empty_varlist) <- names(new_ineq_list)
  
  for(p in 1:length(summarised_ineqs)) {summarised_ineqs[[p]] <- empty_varlist}
  
  
  for(j in 1:length(new_ineq_list)) {
    for (k in 1:length(new_ineq_list[[j]])) {
      #print(names(new_ineq_list[[j]])[k])
      y <- new_ineq_list[[j]][[k]]
      
      a<-y %>%
        select(all_of(comp_names))
      
      ratio_ind <- which(colnames(y) == ratio_col_ineqs) 
      
      b <- y[,ratio_ind]
      b[grep("Abs|Absolute",b, ignore.case = T)] <- 0
      b<-as.numeric(b)
      y[,ratio_ind] <- b
      
      compies <- levels(as.factor(a[,1]))
      
      for (i in 1:length(compies)) {
        z <- y%>% 
          filter(get(comp_names) %in% compies[i]) %>%
          select(!all_of(comp_names))
        
        rat <- z%>% 
          select(all_of(ratio_col_ineqs))
        rat <- rat[1,1]
        
        ### MINIMUM/LOWER CONSTRAINTS _________________________________________________
        # 1st for minimum/lower constraint - 1st column  
        min_index <- grep("min|lower", colnames(z), ignore.case = T)
        vec <- z[,min_index]
        vec <- vec[which(is.na(vec) == FALSE)]
        
        
        if(is.na(rat)) {rat <- 0}
        if(rat == 0) {
          vec <- as.numeric(vec)
          minval <- min(vec)
          x<-paste0(compies[i],names(new_ineq_list)[j]," > ",minval)
          # print(x)
          summarised_ineqs[[k]][[j]] <- c(summarised_ineqs[[k]][[j]],x)
        } else {if(length(vec[which(is.na(as.numeric(vec)) == TRUE)]) == 0) {vec <- as.numeric(vec)} # if none of the entries in the vector are NAs when made to numeric, then convert all to numeric
          
          ## if the values are NUMERIC - choose the minimum and print the inequality
          if (class(vec)=="numeric") {minval <- min(vec)
          x<-paste0(compies[i],names(new_ineq_list)[j]," > ",compies[i],"*",minval)
          # print(x)
          summarised_ineqs[[k]][[j]] <- c(summarised_ineqs[[k]][[j]],x)
          }
          
          ## if the values are CHARACTER:
          
          if (class(vec)=="character") {minval <- vec[1]                    # choose the first one as the inequality (assumption same value for group)
          
          
          if (length(grep("*", minval, fixed = T, value = T)) > 0) {        # if the value uses * for multiplication or nothing for multiplication
            split<-strsplit(minval,"*",fixed =T)
          } else {split<-strsplit(minval, "(?=[A-Za-z])(?<=[0-9])|(?=[0-9])(?<=[A-Za-z])", perl=TRUE)} # get same outcome of splitting chars up
          
          split <- unlist(split)
          split <- trimws(split)
          letter.ind <- which(is.na(as.numeric(split)))                                               # chars that can become numeric are fine, letters become NA
          
          for(n in letter.ind) {
            p <- split[n]
            
            # consumption
            if (length(grep("\\bconsumption\\b|\\bcons\\b|\\bc\\b|\\bingestion\\b|\\bing\\b|\\bi\\b|\\bq\\b|\\bingest\\b|\\consumpt\\b|\\bconsump\\b|\\bconsum\\b|\\bgpp\\b", p,ignore.case = T)) == 1) {split[n] <- cons}
            
            #production
            if (length(grep("\\bproduction\\b|\\bprod\\b|\\bp\\b|\\bproduct\\b|\\bproductivity\\b|\\bnpp\\b", p,ignore.case = T)) == 1) {split[n] <- prod}
            
            # respiration
            if(resp_element != "none") {if (length(grep("\\brespiration\\b|\\bresp\\b|\\br\\b|\\brespire\\b|\\bbmr\\b|\\bbasal metabolic rate\\b|\\bbase met rate\\b|\\bbasal metab rate\\b", 
                                                        p,ignore.case = T)) == 1) {split[n] <- resp}}
            
            # unused
            if (length(grep("\\begestion\\b|\\begest\\b|\\be\\b|\\bexcretion\\b|\\bexcrete\\b|\\bpoo\\b|\\bdefecation\\b|\\bdefecate\\b|\\bdefaecate\\b|\\bdefaecation\\b|\\bfeces\\b|\\bfaeces\\b
                   |\\bunused\\b|\\bu\\b|\\bunidentified\\b|\\buseless\\b|\\bunused\\b|\\bun\\b|\\bunu\\b|\\bunused_energy\\b", 
                            p,ignore.case = T)) == 1) {split[n] <- unused}
            
            # assimilation efficiency
            if(resp_element != "none") {if (length(grep("\\bassimilation efficiency\\b|\\basseff\\b|\\bA\\b|\\bAE\\b|\\bassimeff\\b|\\bassim eff\\b|\\bass effic\\b|\\basseffic\\b|\\bass\\b|\\bassim\\b|\\bassimilation efficiencies\\b|\\bassimilation\\b",
                                                        p,ignore.case = T)) == 1) {split[n] <- assim}}
            
          }
          
          # if there is more than 1 character value (i.e. more than one NA)
          if(length(letter.ind) > 1) {
            let.link <- paste(split[letter.ind],collapse=paste0("*",compies[i],collapse = ""))   # paste the letters together with the compartment
          } else{let.link <- split[letter.ind]}                                                 # otherwise just leave the one by itself
          
          
          if(length(split[-letter.ind]) == 0) {
            x<-paste0(compies[i], names(new_ineq_list)[j]," > ", compies[i],let.link)
            # print(x)
            summarised_ineqs[[k]][[j]] <- c(summarised_ineqs[[k]][[j]],x)  
          } else {
            num.link <- paste0(split[-letter.ind], collapse = "*")                                # paste the numbers together with multiplication sign, so they are one character 
            # and not a vector. Vector misbehave when pasting for this purpose
            x<-paste0(compies[i], names(new_ineq_list)[j]," > ",num.link,"*", compies[i],let.link)
            #print(x)
            summarised_ineqs[[k]][[j]] <- c(summarised_ineqs[[k]][[j]],x)     # paste them all together for final ineqaulity
          }
          }                   #paste them all together for final ineqaulity
        }
        ###_____________________________________________________________________________
        
        ### MAXIMUM/UPPER CONSTRAINTS
        # 1st for minimum/lower constraint - 1st column  
        max_index <- grep("max|upper", colnames(z), ignore.case = T)
        vec <- z[,max_index]
        vec <- vec[which(is.na(vec) == FALSE)]
        
        
        if(rat == 0) {
          vec <- as.numeric(vec)
          maxval <- max(vec)
          x<-paste0(compies[i],names(new_ineq_list)[j]," < ",maxval)
          #print(x)
          summarised_ineqs[[k]][[j]] <- c(summarised_ineqs[[k]][[j]],x)
        } else {if(length(vec[which(is.na(as.numeric(vec)) == TRUE)]) == 0) {vec <- as.numeric(vec)}
          
          ## if the values are NUMERIC - choose the max and print the inequality
          if (class(vec)=="numeric") {maxval <- max(vec)
          x <- paste0(compies[i], names(new_ineq_list)[j]," < ",compies[i],"*",maxval)
          #print(x)
          summarised_ineqs[[k]][[j]] <- c(summarised_ineqs[[k]][[j]],x)}
          
          
          ## if the values are CHARACTER:
          
          if (class(vec)=="character") {maxval <- vec[1]                    # choose the first one as the inequality (assumption same value for group)
          
          
          if (length(grep("*", maxval, fixed = T, value = T)) > 0) {        # if the value uses * for multiplication or nothing for multiplication
            split<-strsplit(maxval,"*",fixed =T)
          } else {split<-strsplit(maxval, "(?=[A-Za-z])(?<=[0-9])|(?=[0-9])(?<=[A-Za-z])", perl=TRUE)} # get same outcome of splitting chars up
          
          split <- unlist(split)
          letter.ind <- which(is.na(as.numeric(split)))                                               # chars that can become numeric are fine, letters become NA
          
          for(n in letter.ind) {
            p <- split[n]
            
            # consumption
            if (length(grep("\\bconsumption\\b|\\bcons\\b|\\bc\\b|\\bingestion\\b|\\bing\\b|\\bi\\b|\\bq\\b|\\bingest\\bconsumpt\\b|\\bconsump\\b|\\bconsum\\b|\\bgpp\\b", p,ignore.case = T)) == 1) {split[n] <- cons}
            
            #production
            if (length(grep("\\bproduction\\b|\\bprod\\b|\\bp\\b|\\bproduct\\b|\\bproductivity\\b|\\bnpp\\b", p,ignore.case = T)) == 1) {split[n] <- prod}
            
            # respiration
            if(resp_element != "none") {if (length(grep("\\brespiration\\b|\\bresp\\b|\\br\\b|\\brespire\\b|\\bbmr\\b|\\bbasal metabolic rate\\b|\\bbase met rate\\b|\\bbasal metab rate\\b", 
                                                        p,ignore.case = T)) == 1) {split[n] <- resp}}
            
            # unused
            if (length(grep("\\begestion\\b|\\begest\\b|\\be\\b|\\bexcretion\\b|\\bexcrete\\b|\\bpoo\\b|\\bdefecation\\b|\\bdefecate\\b|\\bdefaecate\\b|\\bdefaecation\\b|\\bfeces\\b|\\bfaeces\\b
                   |\\bunused\\b|\\bu\\b|\\bunidentified\\b|\\buseless\\b|\\bunused\\b|\\bun\\b|\\bunu\\b|\\unused_energy\\b", 
                            p,ignore.case = T)) == 1) {split[n] <- unused}
            
            # assimilation efficiency
            if(resp_element != "none") {if (length(grep("\\bassimilation efficiency\\b|\\basseff\\b|\\bA\\b|\\bAE\\b|\\bassimeff\\b|\\bassim eff\\b|\\bass effic\\b|\\basseffic\\b|\\bass\\b|\\bassim\\b|\\bassimilation efficiencies\\b|\\bassimilation\\b", 
                                                        p,ignore.case = T)) == 1) {split[n] <- assim}}
            
            
          }
          
          # Obtain letter part and number part of inequality and paste them together
          # if there is more than 1 character value (i.e. more than one NA)
          if(length(letter.ind) > 1) {
            let.link <- paste(split[letter.ind],collapse=paste0("*",compies[i],collapse = ""))   # paste the letters together with the compartment
          } else{let.link <- split[letter.ind]}                                                 # otherwise just leave the one by itself
          
          
          if(length(split[-letter.ind]) == 0) {
            x<-paste0(compies[i], names(new_ineq_list)[j]," < ", compies[i],let.link)
            #print(x)
            summarised_ineqs[[k]][[j]] <- c(summarised_ineqs[[k]][[j]],x)  
          } else {
            num.link <- paste0(split[-letter.ind], collapse = "*")                                # paste the numbers together with multiplication sign, so they are one character 
            # and not a vector. Vector misbehave when pasting for this purpose
            x<-paste0(compies[i], names(new_ineq_list)[j]," < ",num.link,"*", compies[i],let.link)
            #print(x)
            summarised_ineqs[[k]][[j]] <- c(summarised_ineqs[[k]][[j]],x)     # paste them all together for final ineqaulity
          }
          }
        }
      }
    }
  }
  
  
  ### FINAL LIST
  
  final_ineqlist <- vector(mode = 'list', length = length(summarised_ineqs))
  names(final_ineqlist) <- names(summarised_ineqs)
  
  for(i in 1:length(summarised_ineqs)) {
    for(j in 1:length(summarised_ineqs[[i]])) {
      x<-summarised_ineqs[[i]][[j]]
      final_ineqlist[[i]] <- c(final_ineqlist[[i]],x,"\n")
    }
  }
  
  
  ## GET RID OF MISSING DATA
  
  for(i in 1:length(final_ineqlist)) {
    x<-grep("Inf|-Inf",final_ineqlist[[i]])
    if(length(x) > 0) {
      final_ineqlist[[i]] <- final_ineqlist[[i]][-x]  
    }
    grep(paste0(c(prod,cons,prim_prod),collapse="&"),final_ineqlist[[i]])
  }
  
  
  ## if there are specified primary producers, finds them and their consumption and production variables
  ## and changes to GPP and NPP
  if(!is.null(prim_prod)) {for(i in 1:length(final_ineqlist)) {
    for(k in 1:length(prim_prod)) {
      to_subC <- paste0(prim_prod[k],cons)
      to_subP <- paste0(prim_prod[k],prod)
      final_ineqlist[[i]] <- gsub(to_subC,paste0(prim_prod[k],"GPP"),final_ineqlist[[i]],ignore.case = T)
      final_ineqlist[[i]] <- gsub(to_subP,paste0(prim_prod[k],"NPP"),final_ineqlist[[i]],ignore.case = T)
    }
  }
  }
  
  
  
  setwd(path)
  dir.create("Inequalities")
  wd<- paste0(path,"/Inequalities", collapse="")
  setwd(wd)
  
  
  for(i in 1:length(final_ineqlist)) {
    writeLines(final_ineqlist[[i]], paste0(names(final_ineqlist)[i],"_inequalities.txt"))  
  }
  
  ### F MATRIX INEQUALITIES
  ## Save diet proportions/inequalities
  dir.create("F-matrix inequalities")
  wd<- paste0(wd,"/F-matrix inequalities")
  setwd(wd)
  
  Fmat_ineqs2<-Fmat_ineqs[!sapply(Fmat_ineqs,is.null)] ## If there are networks without Fmat inequalities, 
  #removes them before writing to list
  
  
  if(!is.null(prim_prod)) {for(i in 1:length(Fmat_ineqs2)) {
    for(k in 1:length(prim_prod)) {
      to_subC <- paste0(prim_prod[k],cons)
      to_subP <- paste0(prim_prod[k],prod)
      Fmat_ineqs2[[i]] <- gsub(to_subC,paste0(prim_prod[k],"GPP"),Fmat_ineqs2[[i]],ignore.case = T)
      Fmat_ineqs2[[i]] <- gsub(to_subP,paste0(prim_prod[k],"NPP"),Fmat_ineqs2[[i]],ignore.case = T)
    }
  }
  }
  
  if(length(Fmat_ineqs2) > 0) {
    for (i in 1:length(Fmat_ineqs2)) {
      writeLines(Fmat_ineqs2[[i]],paste0(names(Fmat_ineqs2[i])," F-matrix inequalities",".txt"))
    }  
  }
  options(warn=0)
  
  message("Inequalities done")
  
  #### CUSTOM DECLARATIONS ####
  if(!is.null(custom_wbk)) {
    
    #wd<- paste0(path,"/Inequalities", collapse="")
    #setwd(wd)
    if(!is.null(pathwd)) {setwd(pathwd)} else {setwd(paste0(work_dir))}
    
    custlist <- netFs
    
    custnames <- openxlsx::getSheetNames(custom_wbk)
    customs <- lapply(custnames,openxlsx::read.xlsx,xlsxFile=custom_wbk) # read in each sheet
    custnames <- gsub(" ","_", custnames)
    names(customs) <- custnames
    customs <- customs[Fnames]
    
    
    custinds <- grep(paste0(names(customs),collapse = "|"),names(custlist), invert = F)
    not_custinds <- grep(paste0(names(customs),collapse = "|"),names(custlist), invert = T)
    custlist[not_custinds] <- NA
    for(j in custinds) {
      custlist[[j]] <- as.data.frame(customs[[j]])
    }
    
    custs <- vector(mode= "list", length = 7)
    names(custs) <- c("cust_comp","cust_ext","cust_par","cust_flow","cust_var","cust_equal","cust_ineq")
    for (p in seq_along(custs)) { custs[[p]] <- custlist}
    
    stocksearch <- paste0(c("comp","stock","biom"), collapse = "|")
    extsearch <- paste0(c("exte|boun|bound|imp|inp|exp"))
    parsearch <- paste0("par|para|param|pars")
    flowsearch <- paste0("flow")
    varsearch <- paste0("var")
    equalsearch <- paste0("\\bequa")
    ineqsearch <- paste0("ineq")
    
    searchlist <- list(stocksearch,extsearch,parsearch,flowsearch,varsearch,equalsearch,ineqsearch)
    names(searchlist) <- c("stock","ext","par","flow","var","equal","ineq")
    
    defaultW <- getOption("warn")
    options(warn = -1)
    
    for(p in seq_along(custs)) {
      for(k in seq_along(custs[[p]])) {
        if(is.data.frame(custs[[p]][[k]])) {
          x <- custs[[p]][[k]]
          stock_ind <- which(colnames(x) == grep(searchlist[[p]],colnames(x),ignore.case = T,value = T))
          if(length(stock_ind) > 0) {
            y <- x[,stock_ind]
            y <- y[which(!is.na(y))]
            if(length(y) == 0) {
              custs[[p]][[k]] <- NA
            } else {custs[[p]][[k]] <- y}
          } else {custs[[p]][[k]] <- NA}
        }
      }
    }
    options(warn = defaultW)
    message("Custom declarations done")
  }
  
  
  
  #### WRITE TO LIMFILE ####
  
  setwd(path)
  dir.create("LIMfiles")
  wd <- paste0(path,"/LIMfiles")
  setwd(wd)
  
  compartments <- "\n## COMPARTMENTS\n"
  end_compartments <- "\n## END COMPARTMENTS\n"
  custom_compartments <- "! Custom compartments"
  
  externals <- "\n## EXTERNALS\n"
  end_externals <- "\n## END EXTERNALS\n"
  
  parameters <- "\n## PARAMETERS\n"
  end_parameters <- "\n## END PARAMETERS\n"
  
  flows <- "\n## FLOWS\n"
  end_flows <- "\n## END FLOWS\n"
  
  variables <- "\n## VARIABLES\n"
  end_variables <- "\n## END VARIABLES\n"
  
  equalities <- "\n## EQUALITIES\n"
  end_equalities <- "\n## END EQUALITIES\n"
  
  inequalities <- "\n## INEQUALITIES\n"
  end_inequalities <- "\n## END INEQUALITIES\n"
  
  authorname <- authorname
  date <- Sys.Date()
  
  ### WEIGHTED
  
  defaultW <- getOption("warn")
  options(warn = -1)
  
  for (i in 1:length(netFs)) {
    n_LC <- length(internal_bioms_list[[i]][-grep("NLNode",internal_bioms_list[[i]], ignore.case = T)])
    n_NLC <- length(grep(paste0(c("NLNode",resp_element),collapse="|"), rownames(netFs[[i]]), ignore.case = T)) 
    n_externals <- length(grep(paste0(c("Input","Export",resp_element),collapse="|"), rownames(netFs[[i]]), ignore.case = T)) # correct
    m<-as.data.frame(netflows[[i]])
    nflow <- nrow(as.data.frame(m[grep("!|\n", m[,1], invert = T),]))
    
    heading <- glue('! {Fnames[i]} LIM Network 
                ! Living compartments: {n_LC} 
                ! Non-living compartments: {n_NLC}
                ! Externals: {n_externals}
                ! Flows: {nflow}
                ! Author: {authorname}
                ! Date: {date}')
    
    x <- list(heading, 
              compartments, internal_bioms_list[[i]],
              if(!is.null(custom_wbk)){if(!is.na(custs$cust_comp[[i]][1])){
                c("\n! Custom compartments", custs$cust_comp[[i]])}},
              end_compartments,
              
              externals,externals_list[[i]],
              if(!is.null(custom_wbk)){if(!is.na(custs$cust_ext[[i]][1])){
                c("\n! Custom externals", custs$cust_ext[[i]])}},
              end_externals, 
              
              
              if(!is.null(custom_wbk)){if(!is.na(custs$cust_par[[i]][1])){
                c(parameters,"\n! Custom parameters", custs$cust_par[[i]], 
                  end_parameters)}},
              
              
              flows, netflows[[i]], 
              if(!is.null(custom_wbk)){if(!is.na(custs$cust_flow[[i]][1])){
                c("\n! Custom flows", custs$cust_flow[[i]])}},
              end_flows, 
              
              variables,net_vars[[i]],
              if(!is.null(custom_wbk)){if(!is.na(custs$cust_var[[i]][1])){
                c("\n! Custom variables", custs$cust_var[[i]])}},
              end_variables, 
              
              if(!is.null(custom_wbk)){if(!is.na(custs$cust_equal[[i]][1])){
                c(equalities,"\n! Custom equalities", custs$cust_equal[[i]], 
                  end_equalities)}},
              
              inequalities, final_ineqlist[[i]],
              "\n!F-matrix inequalities\n", Fmat_ineqs[[i]],
              if(!is.null(custom_wbk)){if(!is.na(custs$cust_ineq[[i]])[1]){
                c("\n! Custom inequalities", custs$cust_ineq[[i]])}},
              end_inequalities)
    
    writeLines(unlist(lapply(x, paste, collapse="\n")),
               paste0(Fnames[i],"_LIM",".lim"))
    
    message(paste0("LIM declaration file created for ",names(netFs)[i]))
    
  }
  
  options(warn = defaultW)
  
  
  ### UNWEIGHTED
  defaultW <- getOption("warn")
  options(warn = -1)
  
  if(unweighted == TRUE) {
    for (i in 1:length(netFs)) {
      n_LC <- length(internal_bioms_list[[i]][-grep("NLNode",internal_bioms_list[[i]], ignore.case = T)])
      n_NLC <- length(grep(paste0(c("NLNode",resp_element),collapse="|"), rownames(netFs[[i]]), ignore.case = T)) 
      n_externals <- length(grep(paste0(c("Input","Export",resp_element),collapse="|"), rownames(netFs[[i]]), ignore.case = T)) # correct
      m<-as.data.frame(netflows[[i]])
      nflow <- nrow(as.data.frame(m[grep("!|\n", m[,1], invert = T),]))
      
      heading <- glue('! {Fnames[i]} LIM Network 
                ! Living compartments: {n_LC} 
                ! Non-living compartments: {n_NLC}
                ! Externals: {n_externals}
                ! Flows: {nflow}
                ! Author: {authorname}
                ! Date: {date}')
      
      x <- list(heading, 
                compartments, internal_bioms_list[[i]],
                if(!is.null(custom_wbk)){if(!is.na(custs$cust_comp[[i]])[1]){
                  c("\n! Custom compartments", custs$cust_comp[[i]])}},
                end_compartments,
                
                externals,externals_list[[i]],
                if(!is.null(custom_wbk)){if(!is.na(custs$cust_ext[[i]])[1]){
                  c("\n! Custom externals", custs$cust_ext[[i]])}},
                end_externals, 
                
                
                if(!is.null(custom_wbk)){if(!is.na(custs$cust_par[[i]])[1]){
                  c(parameters,"\n! Custom parameters", custs$cust_par[[i]], 
                    end_parameters)}},
                
                
                flows, netflows[[i]], 
                if(!is.null(custom_wbk)){if(!is.na(custs$cust_flow[[i]])[1]){
                  c("\n! Custom flows", custs$cust_flow[[i]])}},
                end_flows, 
                
                variables,net_vars[[i]],
                if(!is.null(custom_wbk)){if(!is.na(custs$cust_var[[i]])[1]){
                  c("\n! Custom variables", custs$cust_var[[i]])}},
                end_variables)
      
      writeLines(unlist(lapply(x, paste, collapse="\n")),
                 paste0("unweighted_",Fnames[i],"_LIM",".lim"))
      
      message(paste0("Unweighted LIM declaration file created for ",names(netFs)[i]))
      
    }
  }
  options(warn = defaultW)
  
  message("All LIMfiles written")
  
  if(!is.null(pathwd)) {setwd(pathwd)} else {setwd(paste0(work_dir))}
}

#### END DEFINING FUNCTION ####



#### Run using 4node ####

## long version
autoLIMR(Fmats_wbk = "4node_Fmats.xlsx", 
         biom_ineq_wbk = "4node_bioms_ineqs.xlsx",
         compartment_col = "Compartment name", 
         fromto = "Q", 
         compartment_sheet = 1,
         authorname = "User",
         QPRUA = c("Q","P","R","U"), 
         resp_element="CO2", 
         prim_prod = "Plant", 
         ratio_col_ineqs = 2, 
         living = "Alive?", 
         unweighted = TRUE,
         custom_wbk = "4node_custom_declarations.xlsx")

## short version
autoLIMR(Fmats_wbk = "4node_Fmats.xlsx", 
         biom_ineq_wbk = "4node_bioms_ineqs.xlsx",
         prim_prod = "Plant")




# HI DANE