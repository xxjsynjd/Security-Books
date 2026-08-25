# RUST标准库的基础Trait

## RUST中直接针对泛型实现行为定义和Trait
实现行为或Trait时，可以针对泛型来实现特定的行为和Trait，并可以给泛型添加限制以描述。可以添加的泛型限制有：无限制，泛型的原生指针（可变/不可变）类型，泛型的引用(可变/不可变)类型，泛型的数组类型，泛型的切片类型，泛型的切片引用（可变/不可变）类型，泛型的元组（可变/不可变）类型，函数类型， 需实现特定的Trait限制等。
对某个具有针对泛型的类型结构体实现行为和Trait时，也可以对类型结构体的泛型做出如上所述的限制。
举例说明：
```rust
//为所有的类型实现了Borrow<T> Trait
impl<T: ?Sized> Borrow<T> for T {
    fn borrow(&self) -> &T {
        self
    }
}
//为所有的引用类型实现Receiver Trait
impl<T: ?Sized> Receiver for &T {}

//为所有可变引用类型实现Receiver Trait
impl<T: ?Sized> Receiver for &mut T {}

//为所有原生不可变指针类型实现Clone Trait
impl<T: ?Sized> Clone for *const T {
     fn clone(&self) -> Self {
         *self
     }
 }
//为原生可变指针类型实现Clone Trait
impl<T: ?Sized> Clone for *mut T {
     fn clone(&self) -> Self {
         *self
     }
}

//为切片类型[T]实现AsRef<[T]> Trait
impl<T> AsRef<[T]> for [T] {
    fn as_ref(&self) -> &[T] {
        self
    }
}


// 切片的行为 具体实现的片段
// [T;N]代表数组类型，[T]代表切片类型，
// 下面是针对所有切片类型的统一行为。
impl<T> [T] {
    pub const fn len(&self) -> usize {
        unsafe { crate::ptr::PtrRepr { const_ptr: self }.components.metadata }
    }

    pub const fn is_empty(&self) -> bool {
        self.len() == 0
    }
    
    //以下代码展示了RUST代码的极简洁及易理解
    pub const fn first(&self) -> Option<&T> {
        if let [first, ..] = self { Some(first) } else { None }
    }

    pub const fn split_first(&self) -> Option<(&T, &[T])> {
        if let [first, tail @ ..] = self { Some((first, tail)) } else { None }
    }

    pub unsafe fn split_at_unchecked(&self, mid: usize) -> (&[T], &[T]) {
        unsafe { (self.get_unchecked(..mid), self.get_unchecked(mid..)) }
    }
    ...
    ...
}

//原生指针 具体事项行为的片段
impl<T: ?Sized> *const T {
    pub const fn is_null(self) -> bool {
        (self as *const u8).guaranteed_eq(null())
    }

    /// Casts to a pointer of another type.
    pub const fn cast<U>(self) -> *const U {
        self as _
    }

    pub unsafe fn as_ref<'a>(self) -> Option<&'a T> {
        if self.is_null() { None } else { unsafe { Some(&*self) } }
    }
    ...
    ...
}

//原生数组指针 具体行为实现片段。需要注意，原生数组指针也是原生指针，
//此处不应该再实现 *const T的同名函数。
impl<T> *const [T] {
    pub const fn len(self) -> usize {
        metadata(self)
    }

    pub const fn as_ptr(self) -> *const T {
        self as *const T
    }
    ...
    ...
}
// 对&A实现PartialEq<&B> Trait, 如果A实现了 PartialEQ<B>
impl<A: ?Sized, B: ?Sized> PartialEq<&B> for &A
    where
        A: PartialEq<B>,
 {
     fn eq(&self, other: &&B) -> bool {
         PartialEq::eq(*self, *other)
     }
     fn ne(&self, other: &&B) -> bool {
         PartialEq::ne(*self, *other)
     }
}
```
针对限制的泛型实现行为和Trait大幅的减少了代码，受限制的泛型是RUST提供的强大的泛型语法。

## 编译器内置Trait代码分析
分析编译器内置Trait源代码发现源代码文件中的大部分内容实际上是参考文档。
本节主要给出对参考文档理解后的一些总结
```rust
//Send Trait
pub unsafe auto trait Send {
    // empty.
}
//原生指针不支持Send Trait实现，利用"!"表示明确的对Trait的不支持
impl<T: ?Sized> !Send for *const T {}
impl<T: ?Sized> !Send for *mut T {}

mod impls {
    // 实现Sync的类型的类型不可变引用支持Send
    unsafe impl<T: Sync + ?Sized> Send for &T {}
    // 实现Send的类型的类型可变引用支持 Send
    unsafe impl<T: Send + ?Sized> Send for &mut T {}
}

// Sync Trait
pub unsafe auto trait Sync {
    // Empty
}
//原生指针不支持Sync Trait
impl<T: ?Sized> !Sync for *const T {}
impl<T: ?Sized> !Sync for *mut T {}

pub trait Sized {
    // Empty.
}

//如果一个Sized的类型要强制转换为动态大小类型，那必须实现Unsize Trait
//例如 [T;N] 实现了 Unsize<[T]>
pub trait Unsize<T: ?Sized> {
    // Empty.
}

//模式匹配表达式匹配时编译器需要使用的Trait，如果一个结构实现了PartialEq，该Trait会自动被实现。
//推测这个结构应该是内存按位比较
pub trait StructuralPartialEq {
    // Empty.
}

//主要用于模式匹配，如果一个结构实现了Eq, 该Trait会自动被实现。
pub trait StructuralEq {
    // Empty.
}

//Copy，略
pub trait Copy: Clone {
    // Empty.
}

//统一实现原生类型对Copy Trait的支持
mod copy_impls {

    use super::Copy;

    macro_rules! impl_copy {
        ($($t:ty)*) => {
            $(
                impl Copy for $t {}
            )*
        }
    }

    impl_copy! {
        usize u8 u16 u32 u64 u128
        isize i8 i16 i32 i64 i128
        f32 f64
        bool char
    }

    impl Copy for ! {}

    impl<T: ?Sized> Copy for *const T {}

    impl<T: ?Sized> Copy for *mut T {}

    impl<T: ?Sized> Copy for &T {}

    //& mut T不支持Copy，以保证RUST的借用规则
}

//PhantomData被用来在类型结构体重做一个标记，标记某结构中需要但不必有实体的另一类型属性
//PhantomData具体阐述请参考标准库文档。 
//PhantomData是个单元结构体，单元结构体的变量名就是单元结构体的类型名。
//所以使用的时候直接使用PhantomData即可，编译器会将泛型的类型实例化信息自动带入PhantomData中
pub struct PhantomData<T: ?Sized>;
```

## ops 运算符 Trait 代码分析

RUST中，所有的运算符号都可以重载。
### 一个小规则
在重载函数中，如果重载的符号出現，编译器用规定的默认操作来实现。例如：
```rust
        impl const BitAnd for u8 {
            type Output = u8;
            //下面函数内部的 & 符号不再引发重载，是编译器的默认按位与操作。
            fn bitand(self, rhs: u8) -> u8 { self & u8 }
        }
```
### 数学运算符 Trait
易理解，略
### 位运算符 Trait
易理解，略
### 关系运算 运算符Trait
代码及分析如下
```rust
//允许类型结构体部分相等
pub trait PartialEq<Rhs: ?Sized = Self> {
    /// “==” 重载行为
    fn eq(&self, other: &Rhs) -> bool;

    /// `!=` 重载行为
    fn ne(&self, other: &Rhs) -> bool {
        !self.eq(other)
    }
}

/// Derive macro generating an impl of the trait `PartialEq`.
/// 实现Derive属性的过程宏
pub macro PartialEq($item:item) {
    /* compiler built-in */
}

//结构体的每个属性都必须相等
pub trait Eq: PartialEq<Self> {
    fn assert_receiver_is_total_eq(&self) {}
}

/// 实现Derive属性的过程宏
pub macro Eq($item:item) {
    /* compiler built-in */
}

//用于表示关系结果的结构体
#[derive(Clone, Copy, PartialEq, Debug, Hash)]
#[repr(i8)]
pub enum Ordering {
    /// An ordering where a compared value is less than another.
    Less = -1,
    /// An ordering where a compared value is equal to another.
    Equal = 0,
    /// An ordering where a compared value is greater than another.
    Greater = 1,
}

impl Ordering {
    pub const fn is_eq(self) -> bool {
        matches!(self, Equal)
    }
    
    //以下函数体实现略
    pub const fn is_ne(self) -> bool 
    pub const fn is_lt(self) -> bool 
    pub const fn is_gt(self) -> bool 
    pub const fn is_le(self) -> bool
    pub const fn is_ge(self) -> bool

    //做反转操作
    pub const fn reverse(self) -> Ordering {
        match self {
            Less => Greater,
            Equal => Equal,
            Greater => Less,
        }
    }

    //用来简化代码及更好的支持函数式编程
    //举例：
    // let x: (i64, i64, i64) = (1, 2, 7);
    // let y: (i64, i64, i64) = (1, 5, 3);
    // let result = x.0.cmp(&y.0).then(x.1.cmp(&y.1)).then(x.2.cmp(&y.2));
    pub const fn then(self, other: Ordering) -> Ordering {
        match self {
            Equal => other,
            _ => self,
        }
    }

    //用来简化代码实及支持函数式编程
    pub fn then_with<F: FnOnce() -> Ordering>(self, f: F) -> Ordering {
        match self {
            Equal => f(),
            _ => self,
        }
    }
}


// "<" ">" ">=" "<=" 运算符重载结构
pub trait PartialOrd<Rhs: ?Sized = Self>: PartialEq<Rhs> {
    fn partial_cmp(&self, other: &Rhs) -> Option<Ordering>;

    // "<" 运算符重载
    fn lt(&self, other: &Rhs) -> bool {
        matches!(self.partial_cmp(other), Some(Less))
    }
    
    //"<="运算符重载
    fn le(&self, other: &Rhs) -> bool {
        // Pattern `Some(Less | Eq)` optimizes worse than negating `None | Some(Greater)`.
        !matches!(self.partial_cmp(other), None | Some(Greater))
    }

    //">"运算符重载
    fn gt(&self, other: &Rhs) -> bool {
        matches!(self.partial_cmp(other), Some(Greater))
    }
    
    //">="运算符重载
    fn ge(&self, other: &Rhs) -> bool {
        matches!(self.partial_cmp(other), Some(Greater | Equal))
    }
}

//实现Derive的过程宏
pub macro PartialOrd($item:item) {
    /* compiler built-in */
}

//用输入的闭包比较函数获取两个值中大的一个
pub fn max_by<T, F: FnOnce(&T, &T) -> Ordering>(v1: T, v2: T, compare: F) -> T {
    match compare(&v1, &v2) {
        Ordering::Less | Ordering::Equal => v2,
        Ordering::Greater => v1,
    }
}

//用输入的闭包比较函数获取两个值中小的一个
pub fn min_by<T, F: FnOnce(&T, &T) -> Ordering>(v1: T, v2: T, compare: F) -> T {
    match compare(&v1, &v2) {
        Ordering::Less | Ordering::Equal => v1,
        Ordering::Greater => v2,
    }
}

//以下代码易理解，略
pub trait Ord: Eq + PartialOrd<Self> {
    fn cmp(&self, other: &Self) -> Ordering;

    fn max(self, other: Self) -> Self
    where
        Self: Sized,
    {
        max_by(self, other, Ord::cmp)
    }

    fn min(self, other: Self) -> Self
    where
        Self: Sized,
    {
        min_by(self, other, Ord::cmp)
    }

    fn clamp(self, min: Self, max: Self) -> Self
    where
        Self: Sized,
    {
        assert!(min <= max);
        if self < min {
            min
        } else if self > max {
            max
        } else {
            self
        }
    }
}
//实现Drive 属性过程宏
pub macro Ord($item:item) {
    /* compiler built-in */
}

pub fn min<T: Ord>(v1: T, v2: T) -> T {
    v1.min(v2)
}

pub fn min_by_key<T, F: FnMut(&T) -> K, K: Ord>(v1: T, v2: T, mut f: F) -> T {
    min_by(v1, v2, |v1, v2| f(v1).cmp(&f(v2)))
}

pub fn max<T: Ord>(v1: T, v2: T) -> T {
    v1.max(v2)
}

pub fn max_by_key<T, F: FnMut(&T) -> K, K: Ord>(v1: T, v2: T, mut f: F) -> T {
    max_by(v1, v2, |v1, v2| f(v1).cmp(&f(v2)))
}


//对于实现了PartialOrd的类型实现一个Ord的反转，这是一个
//adapter的设计模式例子
pub struct Reverse<T>(pub T);

impl<T: PartialOrd> PartialOrd for Reverse<T> {
    fn partial_cmp(&self, other: &Reverse<T>) -> Option<Ordering> {
        other.0.partial_cmp(&self.0)
    }

    fn lt(&self, other: &Self) -> bool {
        other.0 < self.0
    }
    ...
    ...
}

impl<T: Ord> Ord for Reverse<T> {
    fn cmp(&self, other: &Reverse<T>) -> Ordering {
        other.0.cmp(&self.0)
    }
    ...
}

impl<T: Clone> Clone for Reverse<T> {
    fn clone(&self) -> Reverse<T> {
        Reverse(self.0.clone())
    }

    fn clone_from(&mut self, other: &Self) {
        self.0.clone_from(&other.0)
    }
}


// Implementation of PartialEq, Eq, PartialOrd and Ord for primitive types
mod impls {
    use crate::cmp::Ordering::{self, Equal, Greater, Less};
    use crate::hint::unreachable_unchecked;
    
    //PartialEq在原生类型上的实现
    macro_rules! partial_eq_impl {
        ($($t:ty)*) => ($(
            impl PartialEq for $t {
                fn eq(&self, other: &$t) -> bool { (*self) == (*other) }
                fn ne(&self, other: &$t) -> bool { (*self) != (*other) }
            }
        )*)
    }

    impl PartialEq for () {
        fn eq(&self, _other: &()) -> bool {
            true
        }
        fn ne(&self, _other: &()) -> bool {
            false
        }
    }

    partial_eq_impl! {
        bool char usize u8 u16 u32 u64 u128 isize i8 i16 i32 i64 i128 f32 f64
    }

    // Eq，PartialOrd, Ord在原生类型上的实现，略
    ...
    ...
    
    impl PartialEq for ! {
        fn eq(&self, _: &!) -> bool {
            *self
        }
    }

    impl Eq for ! {}

    impl PartialOrd for ! {
        fn partial_cmp(&self, _: &!) -> Option<Ordering> {
            *self
        }
    }

    impl Ord for ! {
        fn cmp(&self, _: &!) -> Ordering {
            *self
        }
    }

    //A实现了PartialEq<B>, PartialOrd<B>后，对&A实现PartialEq<&B>， PartialOrd<&B>
    impl<A: ?Sized, B: ?Sized> PartialEq<&B> for &A
    where
        A: PartialEq<B>,
    {
        fn eq(&self, other: &&B) -> bool {
            //注意这个调用方式，此时不能用self.eq调用。
            //eq方法参数为引用
            PartialEq::eq(*self, *other)
        }
        fn ne(&self, other: &&B) -> bool {
            PartialEq::ne(*self, *other)
        }
    }
    impl<A: ?Sized, B: ?Sized> PartialOrd<&B> for &A
    where
        A: PartialOrd<B>,
    {
        fn partial_cmp(&self, other: &&B) -> Option<Ordering> {
            PartialOrd::partial_cmp(*self, *other)
        }
        fn lt(&self, other: &&B) -> bool {
            PartialOrd::lt(*self, *other)
        }
        ...
        ...
    }

    //如果A实现了Ord Trait, 对&A实现Ord Trait
    impl<A: ?Sized> Ord for &A
    where
        A: Ord,
    {
        fn cmp(&self, other: &Self) -> Ordering {
            Ord::cmp(*self, *other)
        }
    }
    impl<A: ?Sized> Eq for &A where A: Eq {}

    impl<A: ?Sized, B: ?Sized> PartialEq<&mut B> for &mut A
    where
        A: PartialEq<B>,
    {
        fn eq(&self, other: &&mut B) -> bool {
            PartialEq::eq(*self, *other)
        }
        fn ne(&self, other: &&mut B) -> bool {
            PartialEq::ne(*self, *other)
        }
    }

    impl<A: ?Sized, B: ?Sized> PartialOrd<&mut B> for &mut A
    where
        A: PartialOrd<B>,
    {
        fn partial_cmp(&self, other: &&mut B) -> Option<Ordering> {
            PartialOrd::partial_cmp(*self, *other)
        }
        fn lt(&self, other: &&mut B) -> bool {
            PartialOrd::lt(*self, *other)
        }
        ...
        ...
    }
    impl<A: ?Sized> Ord for &mut A
    where
        A: Ord,
    {
        fn cmp(&self, other: &Self) -> Ordering {
            Ord::cmp(*self, *other)
        }
    }
    impl<A: ?Sized> Eq for &mut A where A: Eq {}

    impl<A: ?Sized, B: ?Sized> PartialEq<&mut B> for &A
    where
        A: PartialEq<B>,
    {
        fn eq(&self, other: &&mut B) -> bool {
            PartialEq::eq(*self, *other)
        }
        fn ne(&self, other: &&mut B) -> bool {
            PartialEq::ne(*self, *other)
        }
    }

    impl<A: ?Sized, B: ?Sized> PartialEq<&B> for &mut A
    where
        A: PartialEq<B>,
    {
        fn eq(&self, other: &&B) -> bool {
            PartialEq::eq(*self, *other)
        }
        fn ne(&self, other: &&B) -> bool {
            PartialEq::ne(*self, *other)
        }
    }
}

```
关系运算的运算符重载相对于数学运算符重载和位运算符重载复杂一些，但其逻辑依然是比较简单的。

### ？运算符 Trait代码分析
?操作是RUST支持函数式编程的一个基础。不过即使不用于函数式编程，也可大幅简化代码。
当一个类型实现了Try Trait时。可对这个类型做？操作简化代码。
Try Trait也是try..catch在RUST中的一种实现方式，但从代码的表现形式上更加简化。另外，因为能够返回具体类型，这种实现方式就不仅局限于处理异常，可以扩展到其他类似的场景。
可以定义返回类型的行为，支持链式函数调用。
Try Trait定义如下：
```rust
pub trait Try: FromResidual {
    /// The type of the value produced by `?` when *not* short-circuiting.
    /// ?操作符正常结束的返回值类型
    type Output;

    /// The type of the value passed to [`FromResidual::from_residual`]
    /// as part of `?` when short-circuiting.
    /// ?操作符提前返回的值类型，后继会用实例来说明
    type Residual;

    /// Constructs the type from its `Output` type.
    /// 从Self::Output返回值类型中获得原类型的值
    /// This should be implemented consistently with the `branch` method
    /// such that applying the `?` operator will get back the original value:
    /// 此函数必须符合下面代码的原则，
    /// `Try::from_output(x).branch() --> ControlFlow::Continue(x)`.
    /// 例子：
    /// ```
    /// #![feature(try_trait_v2)]
    /// use std::ops::Try;
    ///
    /// assert_eq!(<Result<_, String> as Try>::from_output(3), Ok(3));
    /// assert_eq!(<Option<_> as Try>::from_output(4), Some(4));
    /// assert_eq!(
    ///     <std::ops::ControlFlow<String, _> as Try>::from_output(5),
    ///     std::ops::ControlFlow::Continue(5),
    /// );
    fn from_output(output: Self::Output) -> Self;

    /// branch函数会返回ControlFlow，据此决定流程继续还是提前返回
    /// 例子：
    /// ```p
    /// #![feature(try_trait_v2)]
    /// use std::ops::{ControlFlow, Try};
    ///
    /// assert_eq!(Ok::<_, String>(3).branch(), ControlFlow::Continue(3));
    /// assert_eq!(Err::<String, _>(3).branch(), ControlFlow::Break(Err(3)));
    ///
    /// assert_eq!(Some(3).branch(), ControlFlow::Continue(3));
    /// assert_eq!(None::<String>.branch(), ControlFlow::Break(None));
    ///
    /// assert_eq!(ControlFlow::<String, _>::Continue(3).branch(), ControlFlow::Continue(3));
    /// assert_eq!(
    ///     ControlFlow::<_, String>::Break(3).branch(),
    ///     ControlFlow::Break(ControlFlow::Break(3)),
    /// );
    fn branch(self) -> ControlFlow<Self::Residual, Self::Output>;
}

pub trait FromResidual<R = <Self as Try>::Residual> {
    /// 该函数从提前返回的值中获取原始值
    ///
    /// This should be implemented consistently with the `branch` method such
    /// that applying the `?` operator will get back an equivalent residual:
    /// 此函数必须符合下面代码的原则
    /// `FromResidual::from_residual(r).branch() --> ControlFlow::Break(r)`.
    /// 例子：
    /// ```
    /// #![feature(try_trait_v2)]
    /// use std::ops::{ControlFlow, FromResidual};
    ///
    /// assert_eq!(Result::<String, i64>::from_residual(Err(3_u8)), Err(3));
    /// assert_eq!(Option::<String>::from_residual(None), None);
    /// assert_eq!(
    ///     ControlFlow::<_, String>::from_residual(ControlFlow::Break(5)),
    ///     ControlFlow::Break(5),
    /// );
    /// ```
    fn from_residual(residual: R) -> Self;
}
```
Try Trait对? 操作支持的举例如下：
```rust
//不用? 操作的代码
 pub fn simple_try_fold_3<A, T, R: Try<Output = A>>(
     iter: impl Iterator<Item = T>,
     mut accum: A,
     mut f: impl FnMut(A, T) -> R,
 ) -> R {
     for x in iter {
         let cf = f(accum, x).branch();
         match cf {
             ControlFlow::Continue(a) => accum = a,
             ControlFlow::Break(r) => return R::from_residual(r),
         }
     }
     R::from_output(accum)
 }
// 使用? 操作的代码:
 fn simple_try_fold<A, T, R: Try<Output = A>>(
     iter: impl Iterator<Item = T>,
     mut accum: A,
     mut f: impl FnMut(A, T) -> R,
 ) -> R {
     for x in iter {
         accum = f(accum, x)?;
     }
     R::from_output(accum)
 }
```
由上，可推断出T?表示如下代码
```rust
   match((T as Try).branch()) {
       ControlFlow::Continue(a) => a,
       ControlFlow::Break(r) => return (T as Try)::from_residual(r),
   }
```
ControlFlow类型代码如下, 主要用于指示代码控制流程指示， 逻辑上可类比于continue, break 关键字 代码如下：
```rust
pub enum ControlFlow<B, C = ()> {
    /// Move on to the next phase of the operation as normal.
    Continue(C),
    /// Exit the operation without running subsequent phases.
    Break(B),
    // Yes, the order of the variants doesn't match the type parameters.
    // They're in this order so that `ControlFlow<A, B>` <-> `Result<B, A>`
    // is a no-op conversion in the `Try` implementation.
}


impl<B, C> ops::Try for ControlFlow<B, C> {
    type Output = C;
    // convert::Infallible表示类型不会被使用，可认为是忽略类型,
    //对于Residual只会用ControlFlow::Break(B), 所以用Infallible明确说明不会用到此类型
    type Residual = ControlFlow<B, convert::Infallible>;

    fn from_output(output: Self::Output) -> Self {
        ControlFlow::Continue(output)
    }

    fn branch(self) -> ControlFlow<Self::Residual, Self::Output> {
        match self {
            ControlFlow::Continue(c) => ControlFlow::Continue(c),
            ControlFlow::Break(b) => ControlFlow::Break(ControlFlow::Break(b)),
        }
}

impl<B, C> ops::FromResidual for ControlFlow<B, C> {
    // Infallible表示类型不会被用到
    fn from_residual(residual: ControlFlow<B, convert::Infallible>) -> Self {
        match residual {
            ControlFlow::Break(b) => ControlFlow::Break(b),
        }
    }
}
```
Option的Try Trait实现：
```rust
impl<T> ops::Try for Option<T> {
    type Output = T;
    // Infallible是一种错误类型，但该错误永远也不会发生，这里需要返回None，
    // 所以需要用Option类型，但因为只用None。所以Some使用Infallible来表示不会被使用，这也表现了RUST的安全理念，一定在类型定义的时候保证代码安全。
    type Residual = Option<convert::Infallible>;

    fn from_output(output: Self::Output) -> Self {
        Some(output)
    }

    fn branch(self) -> ControlFlow<Self::Residual, Self::Output> {
        match self {
            Some(v) => ControlFlow::Continue(v),
            None => ControlFlow::Break(None),
        }
    }
}

impl<T> const ops::FromResidual for Option<T> {
    #[inline]
    fn from_residual(residual: Option<convert::Infallible>) -> Self {
        match residual {
            None => None,
        }
    }
}
```
一个Iterator::try_fold()的实现：
```rust
    fn try_fold<B, F, R>(&mut self, init: B, mut f: F) -> R
    where
        Self: Sized,
        F: FnMut(B, Self::Item) -> R,
        R: Try<Output = B>,
    {
        let mut accum = init;
        while let Some(x) = self.next() {
            accum = f(accum, x)?;
        }
        //try 关键字将accum转化为R类型变量
        try { accum }
    }
```
#### 小结
利用Try Trait，程序员可以实现自定义类型的?，提供函数式编程的有力手段并简化代码，提升代码的理解度。

### Range 运算符代码分析
Range是符号 .. , start..end , start.. , ..end , ..=end，start..=end 形式
#### Range相关的边界结构Bound
源代码：
```rust
pub enum Bound<T> {
    /// An inclusive bound.
    /// 边界包括
    Included(T),
    /// An exclusive bound.
    /// 边界不包括
    Excluded(T),
    /// An infinite endpoint. Indicates that there is no bound in this direction.
    /// 边界不存在
    Unbounded,
}
```
Include边界的值包含，Exclued边界的值不包含，Unbounded边界值不存在
#### RangeFull
` ..  `的数据结构。
#### Range<Idx>
`start.. end`的数据结构
#### RangeFrom<Idx>
`start..`的数据结构
#### RangeTo<Idx>
`.. end`的数据结构
#### RangeInclusive<Idx>
`start..=end`的数据结构
#### RangeToInclusive<Idx>
`..=end`的数据结构

#### RangeBounds<T: ?Sized>
所有Range统一实现的Trait。
```rust
pub trait RangeBounds<T: ?Sized> {
    /// 获取范围的起始值
    ///
    /// 例子
    /// # fn main() {
    /// use std::ops::Bound::*;
    /// use std::ops::RangeBounds;
    ///
    /// assert_eq!((..10).start_bound(), Unbounded);
    /// assert_eq!((3..10).start_bound(), Included(&3));
    /// # }
    /// ```
    fn start_bound(&self) -> Bound<&T>;

    /// 获取范围的终止值.
    /// 例子
    /// # fn main() {
    /// use std::ops::Bound::*;
    /// use std::ops::RangeBounds;
    ///
    /// assert_eq!((3..).end_bound(), Unbounded);
    /// assert_eq!((3..10).end_bound(), Excluded(&10));
    /// # }
    /// ```
    fn end_bound(&self) -> Bound<&T>;

    /// 范围是否包括某个值.
    /// 例子
    /// assert!( (3..5).contains(&4));
    /// assert!(!(3..5).contains(&2));
    ///
    /// assert!( (0.0..1.0).contains(&0.5));
    /// assert!(!(0.0..1.0).contains(&f32::NAN));
    /// assert!(!(0.0..f32::NAN).contains(&0.5));
    /// assert!(!(f32::NAN..1.0).contains(&0.5));
    fn contains<U>(&self, item: &U) -> bool
    where
        T: PartialOrd<U>,
        U: ?Sized + PartialOrd<T>,
    {
        (match self.start_bound() {
            Included(start) => start <= item,
            Excluded(start) => start < item,
            Unbounded => true,
        }) && (match self.end_bound() {
            Included(end) => item <= end,
            Excluded(end) => item < end,
            Unbounded => true,
        })
    }
}

```
RangeBounds针对RangeFull，RangeTo, RangeInclusive, RangeToInclusive, RangeFrom, Range结构都进行了实现。同时针对(Bound<T>, Bound<T>)的元组做了实现。

#### Range的独立性
Range操作符多用于与Index运算符结合或与Iterator Trait结合使用。在后继的Index运算符和Iterator中会研究Range是如何与他们结合的。

#### 小结
基于泛型的Range类型提供了非常好的语法手段，只要某类型支持排序，那就可以定义一个在此类型基础上实现的Range类型。再结合Index和Iterator, 将高效的实现极具冲击力的代码。

### RUST的Index 运算符代码分析
数组下标符号[]由Index, IndexMut两个Trait完成重载。数组下标符号重载使得程序更有可读性。两个Trait如下定义：
```rust
pub trait Index<Idx: ?Sized> {
    /// The returned type after indexing.
    type Output: ?Sized;

    /// 若果传入的参数超过内存界限将马上引发panic
    fn index(&self, index: Idx) -> &Self::Output;
}

pub trait IndexMut<Idx: ?Sized>: Index<Idx> {
    fn index_mut(&mut self, index: Idx) -> &mut Self::Output;
}
```
#### 切片数据结构[T]的Index实现

```rust
impl<T, I> ops::Index<I> for [T]
where
    I: SliceIndex<[T]>,
{
    type Output = I::Output;

    fn index(&self, index: I) -> &I::Output {
        index.index(self)
    }
}

impl<T, I> ops::IndexMut<I> for [T]
where
    I: SliceIndex<[T]>,
{
    fn index_mut(&mut self, index: I) -> &mut I::Output {
        index.index_mut(self)
    }
}
需要依赖SliceIndex Trait实现[T]的ops::Index。SliceIndex主要是为了实现下标即支持用usize类型取出单一元素，又支持用Range类型取出子slice。
显然，针对不同的Index<Idx>中的泛型Idx，需要实现不同的处理逻辑。SliceIndex的引入是典型的处理这个需求的设计方式。即如果对某一类型实现一个具有泛型的Trait时，如果对于Trait的泛型实例化不同类型，会带来处理逻辑的不同。那就再定义一个辅助Trait，为前Trait的实例化类型实现辅助Trait，在这个辅助Trait的实现中实现不同的处理逻辑。辅助Trait和Trait之间的定义相关性即可参考SliceIndex和Index的定义相关性。

mod private_slice_index {
    use super::ops;
    //在私有模块中定义一个Sealed Trait，后继的SliceIndex继承Sealed。
    //带来的结果是只有在本模块实现了Sealed Trait的类型才能实现SliceIndex
    //即使SliceIndex是公有定义，其他类型仍然不能够实现SliceIndex
    pub trait Sealed {}

    impl Sealed for usize {}
    impl Sealed for ops::Range<usize> {}
    impl Sealed for ops::RangeTo<usize> {}
    impl Sealed for ops::RangeFrom<usize> {}
    impl Sealed for ops::RangeFull {}
    impl Sealed for ops::RangeInclusive<usize> {}
    impl Sealed for ops::RangeToInclusive<usize> {}
    impl Sealed for (ops::Bound<usize>, ops::Bound<usize>) {}
}

pub unsafe trait SliceIndex<T: ?Sized>: private_slice_index::Sealed {
    /// 此类型通常为T或者T的引用，切片，原生指针类型
    type Output: ?Sized;

    // 从slice变量中用self获取Option<Output>变量
    fn get(self, slice: &T) -> Option<&Self::Output>;

    fn get_mut(self, slice: &mut T) -> Option<&mut Self::Output>;

    //slice是序列的头指针，后面的具体实现会看到为什么用 *const T
    unsafe fn get_unchecked(self, slice: *const T) -> *const Self::Output;

    unsafe fn get_unchecked_mut(self, slice: *mut T) -> *mut Self::Output;
    
    //如果self超出slice的安全范围，会panic
    fn index(self, slice: &T) -> &Self::Output;

    fn index_mut(self, slice: &mut T) -> &mut Self::Output;
}

unsafe impl<T> SliceIndex<[T]> for usize {
    type Output = T;

    fn get(self, slice: &[T]) -> Option<&T> {
        // 必须转化为*const T才能够用指针加方式来获取
        if self < slice.len() { unsafe { Some(&*self.get_unchecked(slice)) } } else { None }
    }

    fn get_mut(self, slice: &mut [T]) -> Option<&mut T> {
        if self < slice.len() { unsafe { Some(&mut *self.get_unchecked_mut(slice)) } } else { None }
    }

    unsafe fn get_unchecked(self, slice: *const [T]) -> *const T {
        //相当于C的指针加操作
        unsafe { slice.as_ptr().add(self) }
    }

    unsafe fn get_unchecked_mut(self, slice: *mut [T]) -> *mut T {
        unsafe { slice.as_mut_ptr().add(self) }
    }

    fn index(self, slice: &[T]) -> &T {
        // N.B., use intrinsic indexing 此处应该可以用get,但应该是编译器内置支持，为了效率直接使用了内置的数组下标表示。
        &(*slice)[self]
    }

    fn index_mut(self, slice: &mut [T]) -> &mut T {
        // N.B., use intrinsic indexing
        &mut (*slice)[self]
    }
}
```
以上就是针对[T]的以无符号数作为下标取出单一元素的ops::Index 及 ops::IndexMut的底层实现，从slice中取出单一元素必须应用ptr的操作。

```rust
unsafe impl<T> SliceIndex<[T]> for ops::Range<usize> {
    type Output = [T];

    fn get(self, slice: &[T]) -> Option<&[T]> {
        if self.start > self.end || self.end > slice.len() {
            None
        } else {
            unsafe { Some(&*self.get_unchecked(slice)) }
        }
    }

    fn get_mut(self, slice: &mut [T]) -> Option<&mut [T]> {
        if self.start > self.end || self.end > slice.len() {
            None
        } else {
            unsafe { Some(&mut *self.get_unchecked_mut(slice)) }
        }
    }

    unsafe fn get_unchecked(self, slice: *const [T]) -> *const [T] {
        // 利用ptr的内存操作形成* const [T] 原生指针
        unsafe { ptr::slice_from_raw_parts(slice.as_ptr().add(self.start), self.end - self.start) }
    }

    unsafe fn get_unchecked_mut(self, slice: *mut [T]) -> *mut [T] {
        unsafe {
            ptr::slice_from_raw_parts_mut(slice.as_mut_ptr().add(self.start), self.end - self.start)
        }
    }

    fn index(self, slice: &[T]) -> &[T] {
        if self.start > self.end {
            slice_index_order_fail(self.start, self.end);
        } else if self.end > slice.len() {
            slice_end_index_len_fail(self.end, slice.len());
        }
        //将* const [T]转化为切片引用
        unsafe { &*self.get_unchecked(slice) }
    }

    fn index_mut(self, slice: &mut [T]) -> &mut [T] {
        if self.start > self.end {
            slice_index_order_fail(self.start, self.end);
        } else if self.end > slice.len() {
            slice_end_index_len_fail(self.end, slice.len());
        }
        unsafe { &mut *self.get_unchecked_mut(slice) }
    }
}
```
以上是实现用Range从slice中取出子slice的实现。其他如RangeTo等与Range大同小异，这里不再分析。

##### 小结
对于切片的Index, 整体上，需要将切片类型的引用转换为slice元素类型的原生指针，然后对原生指针做加减操作，再根据需要重新建立元素类型或作切片类型的原生指针，然后将原生指针转换为引用。由此可见，ptr和mem模块的熟练使用是必须掌握的。

#### 数组数据结构[T;N]的ops::Index实现

```rust
impl<T, I, const N: usize> Index<I> for [T; N]
where
    [T]: Index<I>,
{
    type Output = <[T] as Index<I>>::Output;

    fn index(&self, index: I) -> &Self::Output {
        Index::index(self as &[T], index)
    }
}

impl<T, I, const N: usize> IndexMut<I> for [T; N]
where
    [T]: IndexMut<I>,
{
    fn index_mut(&mut self, index: I) -> &mut Self::Output {
        IndexMut::index_mut(self as &mut [T], index)
    }
}
```
以上， `self as &[T]` 即把[T;N]转化为了切片[T], 所以数组的Index就是[T]的Index实现

# RUST的Iterator实现代码分析 
## RUST的Iterator与其他语言Iterator比较
RUST定义了三种迭代器Trait:
1. 对容器内的变量进行操作的迭代器：
```rust
pub trait IntoIterator {
    type Item;
    type IntoIter: Iterator<Item = Self::Item>;
    fn into_iter(self) -> Self::IntoIter;
}
```
into_iter返回的迭代器迭代时，会消费容器，完全迭代后容器将被释放。此种迭代器适用于类似生产者-消费者队列的程序设计
2. 对容器内的变量不可用引用进行操作的迭代器：
这个一般不做Trait，而是容器类型实现一个行为：
```pub fn iter(&self) -> I:Iterator```
此行为返回一个迭代器，这种迭代器适用的一个例子是对网络接口做遍历以获得统计值
3. 对容器内的变量可变引用进行操作的迭代器：
同2 容器类型实现行为：
```pub fn iter_mut(&self) -> I:Iterator ```
这种迭代器适用的一个例子是定时器遍历长连接，更新连接活动时间。
其他语言中没有变量迭代器，这是RUST独有的所有权和drop机制带来的一种迭代器。在适合的场景下会缩减代码量及提高效率。
一般的，RUST对于实现上面三个Trait，要求额外实现下面的两种机制
T::iter() 等同于 &T::into_iter()
T::iter_mut() 等同于 &mut T::into_iter()

## Iterator Trait 定义
```rust
pub trait Iterator {
    /// The type of the elements being iterated over.
    type Item;
    fn next(&mut self) -> Option<Self::Item>;
    
    //size_hint返回值是此迭代器最少产生多少个有效迭代输出，最多产生多少有有效迭代输出。
    //所以，诸如(0..10).int_iter(), 最少是10个，最多也是10个，
    //而（0..10).filter(|x| x%2 == 0), 因为编译器不会提前计算，所以符合条件的最少可能是0个，最多是10个
    fn size_hint(&self) -> (usize, Option<usize>) {
        (0, None)
    }
}

impl<I: Iterator + ?Sized> Iterator for &mut I {
    type Item = I::Item;
    fn next(&mut self) -> Option<I::Item> {
        (**self).next()
    }
    fn size_hint(&self) -> (usize, Option<usize>) {
        (**self).size_hint()
    }
    fn advance_by(&mut self, n: usize) -> Result<(), usize> {
        (**self).advance_by(n)
    }
    fn nth(&mut self, n: usize) -> Option<Self::Item> {
        (**self).nth(n)
    }
}
```
上面代码：如果一个类型I已经实现了 Iterator, 那针对这个结构的可变引用类型 &mut I, 标准库已经做了统一的 Iterator Trait实现。

## ops::Range类型的Iterator实现
定义如下：
```rust 
impl<A: Step> Iterator for ops::Range<A> {
        ...
    }
```
只有实现`Step Trait`的Range类型才实现了Iterator, `Step Trait`的定义如下：
```rust
pub trait Step: Clone + PartialOrd + Sized {
    /// 从start 到end一共多少step
    fn steps_between(start: &Self, end: &Self) -> Option<usize>;

    /// 向前count步返回值
    fn forward_checked(start: Self, count: usize) -> Option<Self>;

    /// 向前count步 返回值，出错退出
    fn forward(start: Self, count: usize) -> Self {
        Step::forward_checked(start, count).expect("overflow in `Step::forward`")
    }

    /// 向前不检查 count步
    unsafe fn forward_unchecked(start: Self, count: usize) -> Self {
        Step::forward(start, count)
    }

    /// 向后count步
    fn backward_checked(start: Self, count: usize) -> Option<Self>;

    /// 向后count步，出错退出
    fn backward(start: Self, count: usize) -> Self {
        Step::backward_checked(start, count).expect("overflow in `Step::backward`")
    }
    
    /// 向后count步，出错退出
    unsafe fn backward_unchecked(start: Self, count: usize) -> Self {
        Step::backward(start, count)
    }
}
```
照此，可以实现一个自定义类型的类型, 并支持Step Trait，如此，即可使用Range的符号。例如，一个二维的点的range，三维的点的range，数列等。
一个为所有的无符号类型整数实现的Step Trait中的一个函数：
```rust
                fn forward_checked(start: Self, n: usize) -> Option<Self> {
                    match Self::try_from(n) {
                        Ok(n) => start.checked_add(n),
                        Err(_) => None, // if n is out of range, `unsigned_start + n` is too
                    }
                }
```
从这个函数中可以看到，使用了try_from做了不同的无符号整数类型之间的变换，checked_add来规避溢出，都是RUST的安全性的具体体现，这是使用rust编码与其他语言编码的不同之处,在编码的时候即强制消除了易忽视的整数变量溢出bug产生。

Range Iterator的底层实现Trait RangeIteratorImpl
```rust
impl<A: Step> RangeIteratorImpl for ops::Range<A> {
    type Item = A;

    default fn spec_next(&mut self) -> Option<A> {
        if self.start < self.end {
            //self.start.clone()是为了不转移self.start的所有权
            let n =
                Step::forward_checked(self.start.clone(), 1).expect("`Step` invariants not upheld");
            //mem::replace将self.start赋值为n，返回self.start的值，这个方式适用于任何类型
            Some(mem::replace(&mut self.start, n))
        } else {
            None
        }
    }

    ...
}
```
从代码分析中可见，rust在代码上的技巧性实际上和C在思想上很类似。都是基于对内存的深刻理解。

## slice的Iterator实现

首先定义了适合&[T]的Iter结构：
```rust
pub struct Iter<'a, T: 'a> {
    //当前元素的指针
    ptr: NonNull<T>,
    //尾元素指针，用ptr == end以快速检测iterator是否为空
    end: *const T, 
    //用来表示iterator与容器类型的生命周期关系
    _marker: PhantomData<&'a T>, 
}

//判断Iterator是否为空的宏
macro_rules! is_empty {
    // 可以满足0字节元素的切片及非0字节元素的切片
    ($self: ident) => {
        //Iter::ptr == Iter::end
        $self.ptr.as_ptr() as *const T == $self.end
    };
}

//取Iterator长度的宏
macro_rules! len {
    ($self: ident) => {{
        let start = $self.ptr;
        let size = size_from_ptr(start.as_ptr());
        //判断元素是否为0字节
        if size == 0 {
            // 用end减start得到0字节元素的切片长度
            ($self.end as usize).wrapping_sub(start.as_ptr() as usize)
        } else {
            //非0字节，用内存字节数除以单元素长度
            let diff = unsafe { unchecked_sub($self.end as usize, start.as_ptr() as usize) };
            unsafe { exact_div(diff, size) }
        }
    }};
}

//用宏实现Iterator Trait
macro_rules! iterator {
    (
        struct $name:ident -> $ptr:ty,
        $elem:ty,
        $raw_mut:tt,
        {$( $mut_:tt )?},
        {$($extra:tt)*}
    ) => {
        // 正向next函数辅助宏，实际的逻辑见post_inc_start函数
        macro_rules! next_unchecked {
            ($self: ident) => {& $( $mut_ )? *$self.post_inc_start(1)}
        }

        // 反向的next函数
        macro_rules! next_back_unchecked {
            ($self: ident) => {& $( $mut_ )? *$self.pre_dec_end(1)}
        }

        // 0元素next的移动
        macro_rules! zst_shrink {
            ($self: ident, $n: ident) => {
                //0元素数组因为不能移动指针，所以移动尾指针
                $self.end = ($self.end as * $raw_mut u8).wrapping_offset(-$n) as * $raw_mut T;
            }
        }
        
        //具体的行为实现
        impl<'a, T> $name<'a, T> {
            // 从Iterator获得切片.
            fn make_slice(&self) -> &'a [T] {
                // ptr::from_raw_parts，由内存首地址和切片长度创建切片指针，然后转换为引用
                unsafe { from_raw_parts(self.ptr.as_ptr(), len!(self)) }
            }

            //实质的next
            unsafe fn post_inc_start(&mut self, offset: isize) -> * $raw_mut T {
                if mem::size_of::<T>() == 0 {
                    //0字节元素偏移实现，调整end的值，ptr不变
                    zst_shrink!(self, offset);
                    self.ptr.as_ptr()
                } else {
                    //非0字节元素，返回首地址，首地址然后后移正确的字节
                    let old = self.ptr.as_ptr();
                    self.ptr = unsafe { NonNull::new_unchecked(self.ptr.as_ptr().offset(offset)) };
                    old
                }
            }

            // 从尾部做Iterator的实际实现函数
            unsafe fn pre_dec_end(&mut self, offset: isize) -> * $raw_mut T {
                if mem::size_of::<T>() == 0 {
                    //对于0字节元素，从头部及从尾部逻辑相同
                    zst_shrink!(self, offset);
                    self.ptr.as_ptr()
                } else {
                    //尾部的end即偏移后的位置。
                    self.end = unsafe { self.end.offset(-offset) };
                    self.end
                }
            }
        }

        //Iterator的实现
        impl<'a, T> Iterator for $name<'a, T> {
            type Item = $elem;

            #[inline]
            fn next(&mut self) -> Option<$elem> {
                unsafe {
                    //安全性确认
                    assume(!self.ptr.as_ptr().is_null());
                    if mem::size_of::<T>() != 0 {
                        assume(!self.end.is_null());
                    }
                    if is_empty!(self) {
                        //Iter为空的话，返回None
                        None
                    } else {
                        //实际调用post_inc_start(1)
                        Some(next_unchecked!(self))
                    }
                }
            }

            fn size_hint(&self) -> (usize, Option<usize>) {
                let exact = len!(self);
                (exact, Some(exact))
            }

            fn count(self) -> usize {
                len!(self)
            }

            fn nth(&mut self, n: usize) -> Option<$elem> {
                //如果n大于Iter的长度，清空
                if n >= len!(self) {
                    if mem::size_of::<T>() == 0 {
                        self.end = self.ptr.as_ptr();
                    } else {
                        unsafe {
                            self.ptr = NonNull::new_unchecked(self.end as *mut T);
                        }
                    }
                    return None;
                }
                // 否则，失效前n-1个元素，然后做neet
                unsafe {
                    self.post_inc_start(n as isize);
                    Some(next_unchecked!(self))
                }
            }

            fn advance_by(&mut self, n: usize) -> Result<(), usize> {
                //取长度与n中的小值
                let advance = cmp::min(len!(self), n);

                //失效advance-1个值
                unsafe { self.post_inc_start(advance as isize) };
                //返回
                if advance == n { Ok(()) } else { Err(advance) }
            }

            //从尾部Iterator
            fn last(mut self) -> Option<$elem> {
                //实质调用post_dec_end(1)
                self.next_back()
            }

            //其他，略
            ...
            ...
            
        }
    }
}


impl<'a, T> Iter<'a, T> {
    pub(super) fn new(slice: &'a [T]) -> Self {
        let ptr = slice.as_ptr();
        // SAFETY: Similar to `IterMut::new`.
        unsafe {
            assume(!ptr.is_null()); 

            let end = if mem::size_of::<T>() == 0 {
                //如果切片元素是0字节类型，end 为 首地址加 切片长度字节。即每个元素一个字节
                (ptr as *const u8).wrapping_add(slice.len()) as *const T 
            } else {
                //end为slice.len() * mem::<T>::size_of()
                ptr.add(slice.len()) 
            };
            
            //PhantomData会做类型推断，带入T的类型和生命周期
            Self { ptr: NonNull::new_unchecked(ptr as *mut T), end, _marker: PhantomData }
        }
    }
    
    ...
    ...
}
//宏声明
iterator! {struct Iter -> *const T, &'a T, const, {/* no mut */}, {}}
```
基本上，一个容器类的Iterator的实现基本上是必须要用ptr及mem模块的函数。

## 字符串切片的Iterator实现探秘
题外话，&str.len()返回字符串切片字节占用数，&str.chars().count()返回字符数目。
字符串切片获取Iterator有如下3个函数
&str::chars() 获得以UTF-8编码的字符串的Iterator
&str::bytes() 获得一个[u8]的Iterator
&str::char_indices() 获得一个元组，第一个成员是字符字节数组的序号，第二个成员是字符本身
bytes()主要用于提高在程序员确定采用ASCII字符串下的运行效率。
我们以&str::chars()的Iterator来看一下具体的实现
```rust
pub struct Chars<'a> {
    //利用slice通用的iter做实例化,实际是一个adapter设计模式
    pub(super) iter: slice::Iter<'a, u8>,
}

pub fn chars(&self) -> Chars<'_> {
    //self.as_bytes()获得一个&[u8]
    Chars { iter: self.as_bytes().iter() }
}
impl<'a> Iterator for Chars<'a> {
    type Item = char;

    fn next(&mut self) -> Option<char> {
        //next_code_point见后面代码分析
        next_code_point(&mut self.iter).map(|ch| {
            unsafe { char::from_u32_unchecked(ch) }
        })
    }

    fn count(self) -> usize {
        // 利用切片iterator的filter来实现
        self.iter.filter(|&&byte| !utf8_is_cont_byte(byte)).count()
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        let len = self.iter.len();
        //最少按四个字节一个字符，最多按一个字节一个字符
        ((len + 3) / 4, Some(len))
    }

    fn last(mut self) -> Option<char> {
        self.next_back()
    }

}

pub fn next_code_point<'a, I: Iterator<Item = &'a u8>>(bytes: &mut I) -> Option<u32> {
    // iterator.next 
    let x = *bytes.next()?;
    if x < 128 {
        //ascii字符
        return Some(x as u32);
    }

    //因为是字符串，此时第二个字节一定会有
    let init = utf8_first_byte(x, 2); 
    //获取下一个字节，一定存在   
    let y = unwrap_or_0(bytes.next());
    let mut ch = utf8_acc_cont_byte(init, y);
    if x >= 0xE0 {
        // 三个字节的UTF-8
        let z = unwrap_or_0(bytes.next());
        let y_z = utf8_acc_cont_byte((y & CONT_MASK) as u32, z);
        ch = init << 12 | y_z;
        if x >= 0xF0 {
            //四个字节的UTF-8
            let w = unwrap_or_0(bytes.next());
            ch = (init & 7) << 18 | utf8_acc_cont_byte(y_z, w);
        }
    }

    Some(ch)
}
```
&str的Iterator实现是一个说明Iterator设计模式优越性的经典实例。如果直接使用循环，则&str与&[T]必然会有很多的重复代码，使用Iterator模式后，重复代码被抽象到了Iterator模块中。&str复用了&[T]的iter。

## array 的Iterator实现

### Unsize Trait
```rust
pub trait Unsize<T: ?Sized> {
    // Empty.
}
```
实现了Unsize Trait，可以把一个固定内存大小的变量强制转换为相关的可变大小类型， 如[T;N]实现了Unsize<[T]>, 因此[T;N]可以转换为[T]，一般是指针转换。

### Iter所用的结构
```rust
pub struct IntoIter<T, const N: usize> {
    /// data是迭代中的数组.
    ///
    /// 这个数组中，只有data[alive]是有效的，访问其他的部分，即data[..alive.start]
    /// 及data[end..]会发生UB
    /// 
    data: [MaybeUninit<T>; N],

    /// 表明数组中有效的范围.
    ///
    /// 必须满足:
    /// - `alive.start <= alive.end`
    /// - `alive.end <= N`
    alive: Range<usize>,
}
```
从后继的代码可以看出，一旦使用了Iterator, 数组便被IntoIter所代替。
```rust
impl<T, const N: usize> IntoIter<T, N> {
    pub fn new(array: [T; N]) -> Self {
        // 
        // 因为RUST特性目前还不支持数组的transmute，所以用了内存跨类型的transmute_copy，此函数将从栈中申请一块内存。
        // 拷贝完毕后，原数组的所有权已经转移到data中，且data也完成了初始化。此时，需要调用mem::forget反应所有权已经失去。
        // mem::forget不会导致内存泄漏。
        unsafe {
            let iter = Self { data: mem::transmute_copy(&array), alive: 0..N };
            mem::forget(array);
            iter
        }
    }

    pub fn as_slice(&self) -> &[T] {
        // SAFETY: We know that all elements within `alive` are properly initialized.
        unsafe {
            //此处调用SliceIndex::<Range>::get_unchecked
            let slice = self.data.get_unchecked(self.alive.clone());
            MaybeUninit::slice_assume_init_ref(slice)
        }
    }

    pub fn as_mut_slice(&mut self) -> &mut [T] {
        unsafe {
            //此处调用SliceIndex::<Range>::get_unchecked_mut
            let slice = self.data.get_unchecked_mut(self.alive.clone());
            MaybeUninit::slice_assume_init_mut(slice)
        }
    }
}

impl<T, const N: usize> Iterator for IntoIter<T, N> {
    type Item = T;
    fn next(&mut self) -> Option<Self::Item> {
        // 下面使用Range的Iterator特性实现next. alive的start会变化，从而导致start之前的数组元素无法再被访问。
        // Option::map完成下标值传递。
        self.alive.next().map(|idx| {
            // SliceIndex::<usize>::get_unchecked, MaybeUninit::<T>::assume_init_read()
            // 前面有过说明，assume_init_read()从堆栈中申请了T大小的内存，然后进行内存拷贝，然后返回变量
            // 此时array元素的所有权转移到返回值。
            unsafe { self.data.get_unchecked(idx).assume_init_read() }
        })
    }
    ...
    ...
}

impl<T, const N: usize> Drop for IntoIter<T, N> {
    // 因为IntoIter使用的内存是调用MaybeUninit::uninit()从栈中获得的, 感觉不释放似乎也没有内存泄漏问题。
    // 此处的必要性还需要再思考。
    fn drop(&mut self) {
        // as_mut_slice()获得所有具有所有权的元素，这些元素需要调用drop来释放。这里，data变量中的元素始终封装在MaybeUninit
        unsafe { ptr::drop_in_place(self.as_mut_slice()) }
    }
}

```
以上需要特别注意所有权的转移和内存drop调用，这是RUST需要特别注意训练的点。
```rust
impl<T, const N: usize> IntoIterator for [T; N] {
    type Item = T;
    type IntoIter = IntoIter<T, N>;

    /// Creates a consuming iterator, that is, one that moves each value out of
    /// the array (from start to end). The array cannot be used after calling
    /// this unless `T` implements `Copy`, so the whole array is copied.
    /// 创建消费型的iterator, 如果T不实现`Copy`, 则调用此函数后，数组不可再被访问。
    fn into_iter(self) -> Self::IntoIter {
        IntoIter::new(self)
    }
}

#[stable(feature = "rust1", since = "1.0.0")]
impl<'a, T, const N: usize> IntoIterator for &'a [T; N] {
    type Item = &'a T;
    type IntoIter = Iter<'a, T>;
    
    //调用了slice::iter(), &[T;N]实质是slice结构[T]
    fn into_iter(self) -> Iter<'a, T> {
        self.iter()
    }
}

#[stable(feature = "rust1", since = "1.0.0")]
impl<'a, T, const N: usize> IntoIterator for &'a mut [T; N] {
    type Item = &'a mut T;
    type IntoIter = IterMut<'a, T>;
    
    //同上
    fn into_iter(self) -> IterMut<'a, T> {
        self.iter_mut()
    }
}
```
对于数组类型，iterator的实现耗费了大量的资源并有很多内存操作。对于数组，尽可能的使用引用的Iterator。

## 切片排序

```rust
/// 插入排序, 复杂度O(n^2).
fn insertion_sort<T, F>(v: &mut [T], is_less: &mut F)
where
    F: FnMut(&T, &T) -> bool,
{
    //排序场景下，基本不能使用iterator
    for i in 1..v.len() {
        shift_tail(&mut v[..i + 1], is_less);
    }
}


/// 将最后的值左移到遇到更小的值.
fn shift_tail<T, F>(v: &mut [T], is_less: &mut F)
where
    F: FnMut(&T, &T) -> bool,
{
    let len = v.len();
    
    // 因为是对泛型排序，RUST的排序算法比较复杂， 需要指出，&mut [T] 保证了外界不会有对数组或数组元素的引用，而数组元素本身的内存
    // 浅拷贝等同于所有权转移，不会出现内存安全问题。
    unsafe {
        if len >= 2 && is_less(v.get_unchecked(len - 1), v.get_unchecked(len - 2)) {
            // ManuallyDrop把drop的权利从rust编译器接管
            let mut tmp = mem::ManuallyDrop::new(ptr::read(v.get_unchecked(len - 1)));
            // CopyOnDrop会在drop的时候做src到dest的拷贝
            let mut hole = CopyOnDrop { src: &mut *tmp, dest: v.get_unchecked_mut(len - 2) };
            ptr::copy_nonoverlapping(v.get_unchecked(len - 2), v.get_unchecked_mut(len - 1), 1);
            
            //正常的排序内存置换操作
            for i in (0..len - 2).rev() {
                if !is_less(&*tmp, v.get_unchecked(i)) {
                    break;
                }

                ptr::copy_nonoverlapping(v.get_unchecked(i), v.get_unchecked_mut(i + 1), 1);
                hole.dest = v.get_unchecked_mut(i);
            }
        }
    }
}
```
由上可见，即使是简单的排序算法，也必须使用mem及ptr和unsafe代码。而排序实际上是最基本的编程，因此若果ptr和mem模块是必须深刻理解的。
