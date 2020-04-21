module TB_WANNIER90
  USE TB_COMMON
  USE TB_BASIS
  USE TB_IO
  implicit none

  interface TB_w90_setup
     module procedure :: setup_w90
  end interface TB_w90_setup

  interface TB_w90_delete
     module procedure :: delete_w90
  end interface TB_w90_delete

  interface TB_w90_Hloc
     module procedure :: Hloc_w90
  end interface TB_w90_Hloc

  interface TB_w90_Zeta
     module procedure :: Zeta_w90_matrix
     module procedure :: Zeta_w90_vector
  end interface TB_w90_Zeta

  interface TB_w90_Self
     module procedure :: Self0_w90
  end interface TB_w90_Self



  abstract interface
     function w90_hk(kpoint,N)
       real(8),dimension(:)      :: kpoint
       integer                   :: N
       complex(8),dimension(N,N) :: w90_hk
     end function w90_hk
  end interface



  type,public :: w90_structure
     character(len=:),allocatable               :: w90_file
     integer                                    :: Num_wann=0
     integer                                    :: Nrpts=0
     integer                                    :: N15=15
     integer                                    :: Qst=0
     integer                                    :: Rst=0
     integer,allocatable,dimension(:)           :: Ndegen
     integer                                    :: Nlat=0
     integer                                    :: Norb=0   
     integer                                    :: Nspin=0
     integer,allocatable,dimension(:,:)         :: Rvec
     real(8),allocatable,dimension(:,:)         :: Rgrid
     complex(8),allocatable,dimension(:,:,:)    :: Hij
     complex(8),allocatable,dimension(:,:)      :: Hloc
     real(8)                                    :: Efermi
     complex(8),allocatable,dimension(:,:)      :: Zeta
     real(8),allocatable,dimension(:,:)         :: Self
     real(8),dimension(3)                       :: BZorigin
     logical                                    :: iRenorm=.false.
     logical                                    :: iFermi=.false.
     logical                                    :: verbose=.false.       
     logical                                    :: status=.false.
  end type w90_structure


  type(w90_structure) :: TB_w90


contains



  !< Setup the default_w90 structure with information coming from specified w90_file
  subroutine setup_w90(w90_file,nlat,nspin,norb,origin,verbose)
    character(len=*),intent(in) :: w90_file
    integer,optional            :: Nlat
    integer,optional            :: Norb
    integer,optional            :: Nspin
    real(8),optional            :: origin(:)
    logical,optional            :: verbose
    logical                     :: verbose_,master=.true.
    integer                     :: unitIO
    integer                     :: Num_wann
    integer                     :: Nrpts
    integer                     :: i,j,ir,a,b
    integer                     :: rx,ry,rz
    real(8)                     :: re,im,origin_(3)
    !
    origin_  = 0d0     ;if(present(origin))origin_(:size(origin))=origin
    verbose_ = .false. ;if(present(verbose))verbose_=verbose    
    !
    TB_w90%w90_file = str(w90_file)
    open(free_unit(unitIO),&
         file=TB_w90%w90_file,&
         status="old",&
         action="read")
    read(unitIO,*)                      !skip first line
    read(unitIO,*) Num_wann !Number of Wannier orbitals
    read(unitIO,*) Nrpts    !Number of Wigner-Seitz vectors
    !
    call delete_w90
    if(.not.set_eivec)stop "setup_w90: set_eivec=false"
    !
    !Massive structure allocation:
    TB_w90%Nlat     = 1 ; if(present(Nlat))TB_w90%Nlat=Nlat
    TB_w90%Norb     = 1 ; if(present(Norb))TB_w90%Norb=Norb
    TB_w90%Nspin    = 1 ; if(present(Nspin))TB_w90%Nspin=Nspin
    !
    TB_w90%Num_wann = Num_wann
    if(Num_wann /= TB_w90%Nlat*TB_w90%Norb)stop "setup_w90: Num_wann != Nlat*Norb"
    TB_w90%Nrpts    = Nrpts
    TB_w90%Qst      = int(Nrpts/TB_w90%N15)
    TB_w90%Rst      = mod(Nrpts,TB_w90%N15)
    allocate(TB_w90%Ndegen(Nrpts))
    allocate(TB_w90%Rvec(Nrpts,3))
    allocate(TB_w90%Rgrid(Nrpts,3))
    allocate(TB_w90%Hij(num_wann*TB_w90%Nspin,num_wann*TB_w90%Nspin,Nrpts))
    allocate(TB_w90%Hloc(num_wann*TB_w90%Nspin,num_wann*TB_w90%Nspin))
    allocate(TB_w90%Zeta(num_wann*TB_w90%Nspin,num_wann*TB_w90%Nspin))
    allocate(TB_w90%Self(num_wann*TB_w90%Nspin,num_wann*TB_w90%Nspin))
    TB_w90%Ndegen   = 0
    TB_w90%Rvec     = 0
    TB_w90%Hij      = zero
    TB_w90%Hloc     = zero
    TB_w90%Zeta     = eye(num_wann*TB_w90%Nspin)
    TB_w90%Self     = 0d0
    TB_w90%Efermi   = 0d0
    TB_w90%verbose  = verbose_
    TB_w90%BZorigin = origin_
    TB_w90%status   =.true.
    !
    !Read Ndegen from file:
    do i=1,TB_w90%Qst
       read(unitIO,*)(TB_w90%Ndegen(j+(i-1)*TB_w90%N15),j=1,TB_w90%N15)
    enddo
    if(TB_w90%Rst/=0)read(unitIO,*)(TB_w90%Ndegen(j+TB_w90%Qst*TB_w90%N15),j=1,TB_w90%Rst)

    !Read w90 TB Hamiltonian (no spinup-spindw hybridizations assumed)
    do ir=1,Nrpts
       do i=1,Num_wann
          do j=1,Num_wann
             !
             read(unitIO,*)rx,ry,rz,a,b,re,im
             !
             TB_w90%Rvec(ir,1)  = rx
             TB_w90%Rvec(ir,2)  = ry
             TB_w90%Rvec(ir,3)  = rz
             TB_w90%Rgrid(ir,:) = rx*ei_x + ry*ei_y + rz*ei_z
             !
             TB_w90%Hij(a,b,ir)=dcmplx(re,im)
             if(TB_w90%Nspin==2)TB_w90%Hij(a+num_wann, b+num_wann, ir)=dcmplx(re,im)
             !
             if( all(TB_w90%Rvec(ir,:)==0) )then
                TB_w90%Hloc(a,b)=dcmplx(re,im)
                if(Nspin==2)TB_w90%Hloc(a+num_wann, b+num_wann)=dcmplx(re,im)
             endif
          enddo
       enddo
    enddo
    close(unitIO)
    !
    TB_w90%Hloc=slo2lso(TB_w90%Hloc,TB_w90%Nlat,TB_w90%Nspin,TB_w90%Norb)
    !
    if(Check_MPI())master = get_master_MPI()
    if(master)then
       write(*,*)
       write(*,'(1A)')         "-------------- H_LDA --------------"
       write(*,'(A,I6)')      "  Number of Wannier functions:   ",TB_w90%num_wann
       write(*,'(A,I6)')      "  Number of Wigner-Seitz vectors:",TB_w90%nrpts
       write(*,'(A,I6,A,I6)') "  Deg rows:",TB_w90%qst," N last row   :",TB_w90%rst
    endif
    !
  end subroutine setup_w90


  subroutine delete_w90()
    if(.not.TB_w90%status)return
    TB_w90%Num_wann=0
    TB_w90%Nrpts=0
    TB_w90%N15=15
    TB_w90%Qst=0
    TB_w90%Rst=0
    TB_w90%Nlat=0
    TB_w90%Norb=0
    TB_w90%Nspin=0
    TB_w90%Efermi=0d0
    TB_w90%verbose=.false.
    deallocate(TB_w90%w90_file)
    deallocate(TB_w90%Ndegen)
    deallocate(TB_w90%Rvec)
    deallocate(TB_w90%Rgrid)
    deallocate(TB_w90%Hij)
    deallocate(TB_w90%Hloc)
    TB_w90%status=.false.
  end subroutine delete_w90


  subroutine Hloc_w90(Hloc)
    real(8),dimension(:,:) :: Hloc
    integer                :: Nlso
    Nlso = TB_w90%Nspin*TB_w90%Num_Wann
    call assert_shape(Hloc,[Nlso,Nlso],"Hloc_w90","Hloc")
    Hloc = TB_w90%Hloc
  end subroutine Hloc_w90





  subroutine Zeta_w90_vector(zeta)
    real(8),dimension(:)          :: zeta
    real(8),dimension(size(zeta)) :: sq_zeta
    integer                       :: Nlso
    Nlso = TB_w90%Nspin*TB_w90%Num_Wann
    call assert_shape(zeta,[Nlso],"Zeta_w90","zeta")
    sq_zeta     = sqrt(zeta)
    TB_w90%zeta = diag(sq_zeta)
    TB_w90%Irenorm=.true.
  end subroutine Zeta_w90_vector
  !
  subroutine Zeta_w90_matrix(zeta)
    real(8),dimension(:,:) :: zeta
    integer                :: Nlso
    Nlso = TB_w90%Nspin*TB_w90%Num_Wann
    call assert_shape(zeta,[Nlso,Nlso],"Zeta_w90","zeta")  
    TB_w90%zeta = sqrt(zeta)
    TB_w90%Irenorm=.true.
  end subroutine Zeta_w90_matrix



  subroutine Self0_w90(Self0)
    real(8),dimension(:,:) :: self0
    integer                :: Nlso
    Nlso = TB_w90%Nspin*TB_w90%Num_Wann
    call assert_shape(self0,[Nlso,Nlso],"Self0_w90","Self0")  
    TB_w90%Self = Self0
    TB_w90%Irenorm=.true.
  end subroutine Self0_w90




  !< generate an internal function to be called in the building procedure
  function w90_hk_model(kvec,N) result(Hk)
    real(8),dimension(:)      :: kvec
    integer                   :: N
    complex(8),dimension(N,N) :: Hk,Hk_f
    complex(8),dimension(N,N) :: Htmp
    integer                   :: nDim,Nso
    integer                   :: i,j,ir
    real(8)                   :: rvec(size(kvec)),rdotk
    !
    if(.not.TB_w90%status)stop "w90_hk_model: TB_w90 was not setup"
    !
    nDim = size(kvec)
    Nso  = TB_w90%Nspin*TB_w90%Num_wann
    if(Nso /= N )stop "w90_hk_model: Nso != N"
    Htmp = zero
    do ir=1,TB_w90%Nrpts
       Rvec = TB_w90%Rgrid(ir,:nDim)
       rdotk= dot_product(Kvec,Rvec)
       do i=1,N
          do j=1,N
             Htmp(i,j)=Htmp(i,j)+TB_w90%Hij(i,j,ir)*dcmplx(cos(rdotk),-sin(rdotk))/TB_w90%Ndegen(ir)
          enddo
       enddo
    enddo
    if(TB_w90%Ifermi)Htmp = Htmp - TB_w90%Efermi*eye(N)
    !
    ! if(TB_w90%Nspin==1)then
    !    Hk = Htmp
    ! else
    Hk =slo2lso(Htmp,TB_w90%Nlat,TB_w90%Nspin,TB_w90%Norb)
    ! endif
    !
    call herm_check(Hk)
    !
    if(TB_w90%Irenorm)then
       Hk   = Hk - TB_w90%Hloc
       Hk_f = (TB_w90%Zeta .x. Hk) .x. TB_w90%Zeta
       Hk   = Hk_f + TB_w90%Hloc + TB_w90%Self
    endif
    !
  end function w90_hk_model






  subroutine herm_check(A)
    complex(8),intent(in) ::   A(:,:)
    integer               ::   row,col,i,j
    row=size(A,1)
    col=size(A,2)
    do i=1,col
       do j=1,row
          if(abs(A(i,j))-abs(A(j,i)) .gt. 1d-12)then
             write(*,'(1A)') "--> NON HERMITIAN MATRIX <--"
             write(*,'(2(1A7,I3))') " row: ",i," col: ",j
             write(*,'(1A)') "  A(i,j)"
             write(*,'(2F22.18)') real(A(i,j)),aimag(A(i,j))
             write(*,'(1A)') "  A(j,i)"
             write(*,'(2F22.18)') real(A(j,i)),aimag(A(j,i))
             stop
          endif
       enddo
    enddo
  end subroutine herm_check


  function slo2lso(Hslo,Nlat,Nspin,Norb) result(Hlso)
    implicit none
    complex(8),dimension(Nlat*Nspin*Norb,Nlat*Nspin*Norb) :: Hslo
    complex(8),dimension(Nlat*Nspin*Norb,Nlat*Nspin*Norb) :: Hlso
    integer                                               :: Nlat,Nspin,Norb
    integer                                               :: iorb,ispin,ilat
    integer                                               :: jorb,jspin,jlat
    integer                                               :: iI,jI,iO,jO
    Hlso=zero
    do ilat=1,Nlat
       do jlat=1,Nlat
          do ispin=1,Nspin
             do jspin=1,Nspin
                do iorb=1,Norb
                   do jorb=1,Norb
                      !
                      iI = iorb + (ilat-1)*Norb + (ispin-1)*Norb*Nlat
                      jI = jorb + (jlat-1)*Norb + (jspin-1)*Norb*Nlat
                      !
                      iO = iorb + (ispin-1)*Norb + (ilat-1)*Norb*Nspin
                      jO = jorb + (jspin-1)*Norb + (jlat-1)*Norb*Nspin
                      !
                      Hlso(iO,jO) = Hslo(iI,jI)
                      !
                   enddo
                enddo
             enddo
          enddo
       enddo
    enddo
  end function slo2lso

END MODULE TB_WANNIER90










